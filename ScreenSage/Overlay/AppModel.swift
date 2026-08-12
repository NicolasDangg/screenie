import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    var prompt = ""
    var conversation = Conversation()
    var streamingResponse = ""
    var errorMessage = ""
    var isWorking = false
    var presentationID = 0

    let settings: AppSettings
    private let history: ChatHistoryStore
    private let providerClient = ProviderClient()
    private var requestTask: Task<Void, Never>?

    init(settings: AppSettings, history: ChatHistoryStore = ChatHistoryStore()) {
        self.settings = settings
        self.history = history
    }

    var answer: String {
        streamingResponse.isEmpty
            ? conversation.messages.last(where: { $0.role == .assistant })?.text ?? ""
            : streamingResponse
    }

    var isExpanded: Bool {
        isWorking || !conversation.messages.isEmpty || !errorMessage.isEmpty
    }

    func startNewConversation() {
        requestTask?.cancel()
        prompt = ""
        conversation = Conversation()
        streamingResponse = ""
        errorMessage = ""
        isWorking = false
        presentationID += 1
    }

    func finishConversation() {
        requestTask?.cancel()
        if conversation.messages.contains(where: { $0.role == .assistant }) {
            conversation.updatedAt = .now
            history.upsert(conversation)
        }
        startNewConversation()
    }

    func prepareForPresentation() {
        startNewConversation()
    }

    func submit() {
        let submittedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedPrompt.isEmpty, !isWorking else { return }
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
                    try await generateTitle(
                        firstPrompt: firstPrompt,
                        firstResponse: response,
                        conversationID: conversationID,
                        provider: provider,
                        model: model,
                        apiKey: apiKey
                    )
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

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
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
