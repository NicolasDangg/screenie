import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var prompt = ""
    var presentationMode = AppPresentationMode.chat
    var conversation = Conversation()
    var streamingResponse = ""
    var errorMessage = ""
    var isWorking = false
    var presentationID = 0
    var taskError = ""
    var taskSchedule: TaskSchedule?
    var isRequestingTaskSchedule = false
    var isParsingTask = false

    let settings: AppSettings
    let taskStore: TaskStore
    private let history: ChatHistoryStore
    private let providerClient = ProviderClient()
    private let mockResponse: String?
    private let mockScheduleResponse: String?
    private let taskParser: @Sendable (String) async throws -> ScreenieTask
    private var requestTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?
    private var taskParsingTask: Task<Void, Never>?
    private var taskParsingID: UUID?

    init(
        settings: AppSettings,
        history: ChatHistoryStore = ChatHistoryStore(),
        taskStore: TaskStore = TaskStore(),
        mockResponse: String? = ProcessInfo.processInfo.environment["SCREENIE_MOCK_RESPONSE"],
        mockScheduleResponse: String? = ProcessInfo.processInfo.environment["SCREENIE_MOCK_SCHEDULE"],
        taskParser: @escaping @Sendable (String) async throws -> ScreenieTask = {
            try await FoundationModelTaskParser.parse($0)
        }
    ) {
        self.settings = settings
        self.history = history
        self.taskStore = taskStore
        self.mockResponse = mockResponse
        self.mockScheduleResponse = mockScheduleResponse
        self.taskParser = taskParser
    }

    var isExpanded: Bool {
        presentationMode == .tasks || isWorking || !conversation.messages.isEmpty || !errorMessage.isEmpty
    }

    func startNewConversation() {
        requestTask?.cancel()
        cancelTaskParsing()
        prompt = ""
        presentationMode = .chat
        conversation = Conversation()
        streamingResponse = ""
        errorMessage = ""
        isWorking = false
        presentationID += 1
    }

    func presentTasks() {
        presentationMode = .tasks
        prompt = ""
        taskError = ""
        presentationID += 1
    }

    func presentChat() {
        cancelTaskParsing()
        presentationMode = .chat
        presentationID += 1
    }

    func requestScheduleHint() {
        let tasks = taskStore.tasks.filter { !$0.isCompleted }
        guard !tasks.isEmpty else {
            taskError = "Add an incomplete task before requesting a schedule hint."
            return
        }
        let apiKey = settings.apiKey(for: .openRouter).trimmingCharacters(in: .whitespacesAndNewlines)
        guard mockScheduleResponse != nil || !apiKey.isEmpty else {
            taskError = "Add an OpenRouter API key in Settings before requesting a schedule hint."
            return
        }

        taskError = ""
        taskSchedule = nil
        isRequestingTaskSchedule = true
        scheduleTask?.cancel()
        scheduleTask = Task {
            defer { isRequestingTaskSchedule = false }
            do {
                if let mockScheduleResponse,
                   let data = mockScheduleResponse.data(using: .utf8) {
                    taskSchedule = try TaskSchedule.decodeContent(data)
                } else {
                    let model = settings.provider == .openRouter ? settings.model : AIProvider.openRouter.defaultModel
                    taskSchedule = try await providerClient.taskSchedule(
                        model: model,
                        apiKey: apiKey,
                        tasks: tasks
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                taskError = error.localizedDescription
            }
        }
    }

    func finishConversation() {
        requestTask?.cancel()
        if conversation.messages.contains(where: { $0.role == .assistant }) {
            conversation.updatedAt = .now
            history.upsert(conversation)
        }
        startNewConversation()
    }

    func submit() {
        let submittedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedPrompt.isEmpty, !isWorking else { return }
        if handleTaskCommand(submittedPrompt) { return }
        if let mockResponse {
            prompt = ""
            errorMessage = ""
            conversation.messages.append(ChatMessage(role: .user, text: submittedPrompt))
            conversation.messages.append(ChatMessage(role: .assistant, text: mockResponse))
            conversation.updatedAt = .now
            return
        }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add an API key in Settings before asking about your screen."
            return
        }

        prompt = ""
        errorMessage = ""
        streamingResponse = ""
        isWorking = true
        conversation.messages.append(ChatMessage(role: .user, text: submittedPrompt))
        conversation.updatedAt = .now

        let conversationID = conversation.id
        let requestMessages = conversation.messages
        let provider = settings.provider
        let model = settings.model
        let apiKey = settings.apiKey

        requestTask?.cancel()
        requestTask = Task {
            defer {
                if conversation.id == conversationID { isWorking = false }
            }
            do {
                let context = try await ScreenContextCapture.capture()
                var response = ""
                for try await delta in providerClient.stream(
                    provider: provider,
                    model: model,
                    apiKey: apiKey,
                    messages: requestMessages,
                    ocrText: context.ocrText,
                    imageData: context.imageData
                ) {
                    try Task.checkCancellation()
                    guard conversation.id == conversationID else { return }
                    response += delta
                    streamingResponse = response
                }

                guard conversation.id == conversationID, !response.isEmpty else { return }
                conversation.messages.append(ChatMessage(role: .assistant, text: response))
                conversation.updatedAt = .now
                streamingResponse = ""

                if conversation.messages.filter({ $0.role == .assistant }).count == 1 {
                    let firstPrompt = conversation.messages.first(where: { $0.role == .user })?.text ?? submittedPrompt
                    conversation.title = Conversation.cleanedTitle("", fallbackPrompt: firstPrompt)
                    history.upsert(conversation)
                    do {
                        try await generateTitle(
                            firstPrompt: firstPrompt,
                            firstResponse: response,
                            conversationID: conversationID,
                            provider: provider,
                            model: model,
                            apiKey: apiKey
                        )
                    } catch is CancellationError {
                        return
                    } catch {
                        // The fallback title is already persisted; title generation is nonessential.
                    }
                }
                history.upsert(conversation)
            } catch is CancellationError {
                return
            } catch {
                guard conversation.id == conversationID else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    private func handleTaskCommand(_ submittedPrompt: String) -> Bool {
        let lowercased = submittedPrompt.lowercased()
        guard lowercased == "/task" || lowercased.hasPrefix("/task ") else { return false }

        presentTasks()
        let entry = submittedPrompt.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty else { return true }
        taskParsingTask?.cancel()
        let parsingID = UUID()
        taskParsingID = parsingID
        isParsingTask = true
        taskParsingTask = Task {
            do {
                let task = try await taskParser(entry)
                try Task.checkCancellation()
                guard taskParsingID == parsingID else { return }
                taskStore.add(task)
            } catch is CancellationError {
            } catch {
                guard taskParsingID == parsingID else { return }
                taskError = error.localizedDescription
            }
            guard taskParsingID == parsingID else { return }
            taskParsingTask = nil
            taskParsingID = nil
            isParsingTask = false
        }
        return true
    }

    private func cancelTaskParsing() {
        taskParsingTask?.cancel()
        taskParsingTask = nil
        taskParsingID = nil
        isParsingTask = false
    }

    private func generateTitle(
        firstPrompt: String,
        firstResponse: String,
        conversationID: UUID,
        provider: AIProvider,
        model: String,
        apiKey: String
    ) async throws {
        let titlePrompt = """
        Generate a concise 2–6 word topic title for this conversation. Return only the title, without quotes, punctuation, or an application name.

        User: \(firstPrompt)
        Assistant: \(firstResponse)
        """
        var generated = ""
        for try await delta in providerClient.stream(
            provider: provider,
            model: model,
            apiKey: apiKey,
            messages: [ChatMessage(role: .user, text: titlePrompt)]
        ) {
            try Task.checkCancellation()
            generated += delta
        }
        guard conversation.id == conversationID else { return }
        conversation.title = Conversation.cleanedTitle(generated, fallbackPrompt: firstPrompt)
        conversation.updatedAt = .now
    }
}
