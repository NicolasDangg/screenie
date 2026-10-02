import Foundation
import Observation

/// Where a submitted prompt is before its answer starts streaming.
enum WorkPhase: Equatable {
    case capturing
    case readingText
    case thinking
}

@MainActor
@Observable
final class AppModel {
    var prompt = ""
    var workPhase: WorkPhase?
    var presentationMode = AppPresentationMode.chat
    var conversation = Conversation()
    var streamingResponse = ""
    var errorMessage = ""
    var isWorking = false
    var presentationID = 0
    var taskError = ""
    var taskSchedule: TaskSchedule?
    var isRequestingTaskSchedule = false
    var isAddingTaskScheduleToCalendar = false
    var didAddTaskScheduleToCalendar = false
    var isParsingTask = false
    /// Text in the task panel's inline field; kept after a failed parse so it can be corrected.
    var taskEntry = ""
    var includeScreenshotForNextMessage = true
    var attachedScreenshot: Data?
    var expandedChatSize = CGSize(width: OverlayLayout.collapsedWidth, height: OverlayLayout.expandedHeight)

    let settings: AppSettings
    let taskStore: TaskStore
    let taskSources: AppleTaskSources
    private let history: ChatHistoryStore
    private let providerClient = ProviderClient()
    private let mockResponse: String?
    private let mockScheduleResponse: String?
    private let taskParser: @Sendable (String) async throws -> ScreenieTask
    private let eventParser: @Sendable (String) async throws -> ParsedEvent
    private let taskScheduleCalendarSync: @MainActor (TaskSchedule) async throws -> Void
    private let conversationGracePeriod: TimeInterval
    private var requestTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?
    private var scheduleCalendarTask: Task<Void, Never>?
    private var taskParsingTask: Task<Void, Never>?
    private var taskParsingID: UUID?
    private var conversationExpiryTask: Task<Void, Never>?
    private var conversationExpiresAt: Date?

    init(
        settings: AppSettings,
        history: ChatHistoryStore = ChatHistoryStore(),
        taskStore: TaskStore = TaskStore(),
        taskSources: AppleTaskSources? = nil,
        mockResponse: String? = ProcessInfo.processInfo.environment["SCREENIE_MOCK_RESPONSE"],
        mockScheduleResponse: String? = ProcessInfo.processInfo.environment["SCREENIE_MOCK_SCHEDULE"],
        taskScheduleCalendarSync: @escaping @MainActor (TaskSchedule) async throws -> Void = {
            try await TaskCalendarSync.shared.add($0)
        },
        taskParser: @escaping @Sendable (String) async throws -> ScreenieTask = {
            try await FoundationModelTaskParser.parse($0)
        },
        eventParser: @escaping @Sendable (String) async throws -> ParsedEvent = {
            try await FoundationModelTaskParser.parseEvent($0)
        },
        conversationGracePeriod: TimeInterval = 60
    ) {
        self.settings = settings
        self.history = history
        self.taskStore = taskStore
        self.taskSources = taskSources ?? AppleTaskSources()
        self.mockResponse = mockResponse
        self.mockScheduleResponse = mockScheduleResponse
        self.taskScheduleCalendarSync = taskScheduleCalendarSync
        self.taskParser = taskParser
        self.eventParser = eventParser
        self.conversationGracePeriod = conversationGracePeriod
    }

    var isExpanded: Bool {
        presentationMode == .tasks || isWorking || !conversation.messages.isEmpty || !errorMessage.isEmpty
    }

    var hasCompletedFirstResponse: Bool {
        conversation.messages.contains { $0.role == .assistant }
    }

    var canToggleScreenshot: Bool {
        hasCompletedFirstResponse && !isWorking
    }

    nonisolated static func shouldIncludeScreenshot(
        hasCompletedFirstResponse: Bool,
        includeScreenshotForNextMessage: Bool
    ) -> Bool {
        !hasCompletedFirstResponse || includeScreenshotForNextMessage
    }

    func startNewConversation() {
        requestTask?.cancel()
        conversationExpiryTask?.cancel()
        conversationExpiryTask = nil
        conversationExpiresAt = nil
        cancelTaskParsing()
        prompt = ""
        presentationMode = .chat
        conversation = Conversation()
        streamingResponse = ""
        errorMessage = ""
        isWorking = false
        workPhase = nil
        includeScreenshotForNextMessage = true
        attachedScreenshot = nil
        presentationID += 1
    }

    /// Reopens a saved conversation so it can be continued. Its screenshot isn't stored,
    /// so the next message captures a fresh one by default.
    func resume(_ saved: Conversation) {
        guard saved.id != conversation.id || presentationMode != .chat else { return }
        requestTask?.cancel()
        conversationExpiryTask?.cancel()
        conversationExpiryTask = nil
        conversationExpiresAt = nil
        cancelTaskParsing()
        persistConversationIfNeeded()
        prompt = ""
        presentationMode = .chat
        conversation = saved
        streamingResponse = ""
        errorMessage = ""
        isWorking = false
        workPhase = nil
        includeScreenshotForNextMessage = true
        attachedScreenshot = nil
        presentationID += 1
    }

    func toggleScreenshotForNextMessage() {
        guard canToggleScreenshot else { return }
        includeScreenshotForNextMessage.toggle()
    }

    func prepareForPresentation() {
        guard let expiresAt = conversationExpiresAt else { return }
        guard expiresAt > .now else {
            startNewConversation()
            return
        }
        conversationExpiryTask?.cancel()
        conversationExpiryTask = nil
        conversationExpiresAt = nil
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
        scheduleCalendarTask?.cancel()
        isAddingTaskScheduleToCalendar = false
        didAddTaskScheduleToCalendar = false
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

    func dismissTaskSchedule() {
        scheduleCalendarTask?.cancel()
        scheduleCalendarTask = nil
        taskSchedule = nil
        taskError = ""
        isAddingTaskScheduleToCalendar = false
        didAddTaskScheduleToCalendar = false
    }

    func addTaskScheduleToCalendar() {
        guard let schedule = taskSchedule,
              !isAddingTaskScheduleToCalendar,
              !didAddTaskScheduleToCalendar else { return }

        taskError = ""
        isAddingTaskScheduleToCalendar = true
        scheduleCalendarTask?.cancel()
        scheduleCalendarTask = Task {
            defer {
                if taskSchedule == schedule {
                    isAddingTaskScheduleToCalendar = false
                    scheduleCalendarTask = nil
                }
            }
            do {
                try await taskScheduleCalendarSync(schedule)
                try Task.checkCancellation()
                guard taskSchedule == schedule else { return }
                didAddTaskScheduleToCalendar = true
            } catch is CancellationError {
                return
            } catch {
                guard taskSchedule == schedule else { return }
                taskError = "Could not add schedule to Apple Calendar: \(error.localizedDescription)"
            }
        }
    }

    func finishConversation() {
        requestTask?.cancel()
        persistConversationIfNeeded()
        startNewConversation()
    }

    func suspendConversation() {
        requestTask?.cancel()
        requestTask = nil
        isWorking = false
        workPhase = nil
        streamingResponse = ""
        persistConversationIfNeeded()

        conversationExpiryTask?.cancel()
        let conversationID = conversation.id
        let expiresAt = Date.now.addingTimeInterval(conversationGracePeriod)
        conversationExpiresAt = expiresAt
        conversationExpiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(max(0, expiresAt.timeIntervalSinceNow)))
            } catch {
                return
            }
            guard let self,
                  self.conversation.id == conversationID,
                  self.conversationExpiresAt == expiresAt else { return }
            self.conversationExpiryTask = nil
            self.conversationExpiresAt = nil
            self.startNewConversation()
        }
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

        let shouldIncludeScreenshot = Self.shouldIncludeScreenshot(
            hasCompletedFirstResponse: hasCompletedFirstResponse,
            includeScreenshotForNextMessage: includeScreenshotForNextMessage
        )

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
        attachedScreenshot = nil

        requestTask?.cancel()
        workPhase = shouldIncludeScreenshot ? .capturing : .thinking
        requestTask = Task {
            defer {
                if conversation.id == conversationID {
                    isWorking = false
                    workPhase = nil
                }
            }
            do {
                var context: ScreenContext?
                if shouldIncludeScreenshot {
                    let screenshot = try await ScreenContextCapture.captureScreenshot()
                    guard conversation.id == conversationID else { return }
                    attachedScreenshot = screenshot.imageData
                    workPhase = .readingText
                    let ocrText = await VisionOCR.recognize(in: screenshot.image)
                    try Task.checkCancellation()
                    guard conversation.id == conversationID else { return }
                    context = ScreenContext(imageData: screenshot.imageData, ocrText: ocrText)
                    workPhase = .thinking
                }
                var response = ""
                for try await delta in providerClient.stream(
                    provider: provider,
                    model: model,
                    apiKey: apiKey,
                    messages: requestMessages,
                    ocrText: context?.ocrText ?? "",
                    imageData: context?.imageData
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

    /// Stops the current request, keeping whatever part of the answer already arrived.
    func stopResponse() {
        guard isWorking else { return }
        requestTask?.cancel()
        requestTask = nil
        isWorking = false
        workPhase = nil
        let partial = streamingResponse
        streamingResponse = ""
        guard !partial.isEmpty else { return }
        conversation.messages.append(ChatMessage(role: .assistant, text: partial))
        conversation.updatedAt = .now
        if conversation.messages.filter({ $0.role == .assistant }).count == 1,
           let firstPrompt = conversation.messages.first(where: { $0.role == .user })?.text {
            conversation.title = Conversation.cleanedTitle("", fallbackPrompt: firstPrompt)
        }
        history.upsert(conversation)
    }

    /// Replaces the last answer by asking the same prompt again with a fresh screenshot.
    func askAgainWithNewScreenshot() {
        guard !isWorking,
              conversation.messages.last?.role == .assistant,
              let userIndex = conversation.messages.lastIndex(where: { $0.role == .user }) else { return }
        prompt = conversation.messages[userIndex].text
        conversation.messages.removeSubrange(userIndex...)
        includeScreenshotForNextMessage = true
        submit()
    }

    private func persistConversationIfNeeded() {
        guard conversation.messages.contains(where: { $0.role == .assistant }) else { return }
        conversation.updatedAt = .now
        history.upsert(conversation)
    }

    private func handleTaskCommand(_ submittedPrompt: String) -> Bool {
        let lowercased = submittedPrompt.lowercased()
        guard lowercased == "/task" || lowercased.hasPrefix("/task ") else { return false }

        presentTasks()
        addTask(entry: String(submittedPrompt.dropFirst(5)))
        return true
    }

    /// Parses a natural-language entry on-device and saves it to the chosen destination:
    /// a screenie task, a reminder, or an event in an Apple calendar.
    func addTask(entry rawEntry: String) {
        let entry = rawEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty else { return }
        taskError = ""
        taskParsingTask?.cancel()
        let parsingID = UUID()
        taskParsingID = parsingID
        isParsingTask = true
        taskParsingTask = Task {
            do {
                await refreshDestinationIfNeeded()
                if case let .calendar(calendarID) = taskSources.effectiveDestination {
                    let event = try await eventParser(entry)
                    try Task.checkCancellation()
                    guard taskParsingID == parsingID else { return }
                    try await taskSources.addEvent(event, to: calendarID)
                } else {
                    let task = try await taskParser(entry)
                    try Task.checkCancellation()
                    guard taskParsingID == parsingID else { return }
                    try await add(task)
                }
                if taskEntry.trimmingCharacters(in: .whitespacesAndNewlines) == entry { taskEntry = "" }
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
    }

    /// Saves a parsed task to the chosen destination. A calendar destination needs a due date and
    /// becomes a one-hour event.
    func add(_ task: ScreenieTask) async throws {
        await refreshDestinationIfNeeded()
        switch taskSources.effectiveDestination {
        case .screenie:
            taskStore.add(task)
        case let .reminders(listID):
            try await taskSources.addReminder(task, to: listID)
        case let .calendar(calendarID):
            guard let start = task.dueDate else { throw TaskEntryParserError.missingEventTime }
            let timing = EventTiming(start: start, end: start.addingTimeInterval(TaskDateResolver.defaultEventDuration), isAllDay: false)
            try await taskSources.addEvent(ParsedEvent(title: task.title, timing: timing, notes: task.notes), to: calendarID)
        }
    }

    /// Lists load lazily, so make sure the chosen destination can be found before falling back to screenie.
    private func refreshDestinationIfNeeded() async {
        guard taskSources.newItemDestination != .screenie, taskSources.destinationTarget == nil else { return }
        await taskSources.refresh()
    }

    func toggleCompletion(of item: TaskAgendaItem) {
        switch item.source {
        case let .task(task):
            taskStore.toggleCompletion(of: task.id)
        case let .reminder(reminder):
            taskSources.setReminder(reminder, completed: !reminder.isCompleted)
        case .event:
            break
        }
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
