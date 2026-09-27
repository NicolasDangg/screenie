import AppKit
import Carbon
import ServiceManagement
import SwiftUI
import XCTest
@testable import ScreenSage

final class ScreenSageTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) -> Date {
        utcCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for asynchronous state change")
    }

    @MainActor
    func testLiveBackdropUsesActiveBehindWindowBlending() {
        let backdrop = LiveBackdropView.makeVisualEffectView()

        XCTAssertEqual(backdrop.blendingMode, .behindWindow)
        XCTAssertEqual(backdrop.material, .hudWindow)
        XCTAssertEqual(backdrop.state, .active)
    }

    func testPermissionSettingsMetadata() {
        XCTAssertEqual(AppPermission.allCases, [.screenRecording, .accessibility, .inputMonitoring])
        XCTAssertEqual(AppPermission.screenRecording.requirement, "Required")
        XCTAssertEqual(AppPermission.accessibility.requirement, "Optional")
        XCTAssertEqual(AppPermission.inputMonitoring.requirement, "Optional")
        XCTAssertTrue(AppPermission.screenRecording.settingsURL.absoluteString.contains("Privacy_ScreenCapture"))
        XCTAssertTrue(AppPermission.accessibility.settingsURL.absoluteString.contains("Privacy_Accessibility"))
        XCTAssertTrue(AppPermission.inputMonitoring.settingsURL.absoluteString.contains("Privacy_ListenEvent"))
    }

    func testAppIdentityAndUsageDescriptions() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String, "screenie")
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "NSScreenCaptureUsageDescription"))
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription"))
    }

    func testAppUsesScreenieAppIcon() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconName") as? String, "AppIcon")
    }

    @MainActor
    func testDefaultProviderConfiguration() {
        XCTAssertEqual(AppSettings.defaultProvider, .openRouter)
        XCTAssertEqual(AIProvider.openRouter.defaultModel, "openai/gpt-5.6-luna")
    }

    @MainActor
    func testAPIKeyIsStoredInLocalPreferences() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.apiKey = "local-secret"

        settings.saveAPIKey()

        XCTAssertEqual(AppSettings(defaults: defaults).apiKey, "local-secret")
        XCTAssertEqual(settings.savedMessage, "API key saved locally")
    }

    func testOverlayUsesChatComposerDimensions() {
        XCTAssertEqual(OverlayLayout.width, 560)
        XCTAssertEqual(OverlayLayout.collapsedWidth, 320)
        XCTAssertEqual(OverlayLayout.collapsedHeight, 80)
        XCTAssertEqual(OverlayLayout.attachedComposerHeight, 110)
        XCTAssertEqual(OverlayLayout.expandedHeight, 530)
        XCTAssertEqual(OverlayLayout.taskHeight, 480)
        XCTAssertEqual(OverlayLayout.controlDiameter, 25.2)
        XCTAssertEqual(OverlayLayout.cornerRadius, 22)
    }

    @MainActor
    func testDisplayFocusPreferenceDefaultsOnAndPersists() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.followFocusedDisplay)

        settings.followFocusedDisplay = false
        XCTAssertFalse(AppSettings(defaults: defaults).followFocusedDisplay)
    }

    func testOpenRouterCatalogKeepsScreenshotChatModels() throws {
        let vision = try JSONDecoder().decode(OpenRouterModel.self, from: Data(#"{"id":"vendor/vision","name":"Vision","architecture":{"input_modalities":["text","image"],"output_modalities":["text"]}}"#.utf8))
        let textOnly = try JSONDecoder().decode(OpenRouterModel.self, from: Data(#"{"id":"vendor/text","name":"Text","architecture":{"input_modalities":["text"],"output_modalities":["text"]}}"#.utf8))

        XCTAssertTrue(vision.supportsScreenChat)
        XCTAssertFalse(textOnly.supportsScreenChat)
    }

    func testOverlayLoadingLabelMatchesScreenContext() {
        XCTAssertEqual(
            OverlayAnswerView.loadingLabel(includesScreenContext: true),
            "Reading screen…"
        )
        XCTAssertEqual(
            OverlayAnswerView.loadingLabel(includesScreenContext: false),
            "Thinking..."
        )
    }

    @MainActor
    func testAssistantResponseBuildsAllCommonLaTeXDelimiters() {
        let source = #"Inline $x^2$ and \(y^2\). Display $$\frac{1}{2}$$ and \[E=mc^2\]. Literal \$5; unmatched $source."#
        let response = AssistantResponseText(text: source)

        XCTAssertEqual(response.text, source)
        _ = response.body
    }

    @MainActor
    func testStreamingResponseAvoidsLaTeXRendererUntilCompletion() {
        let body = OverlayAnswerView(
            messages: [],
            streamingResponse: #"Still streaming \(x^2\)"#,
            errorMessage: "",
            isWorking: true,
            includesScreenContext: true
        ).body

        XCTAssertFalse(containsAssistantResponseText(in: body))
    }

    func testAssistantResponseNormalizesBoxCommandsForMathJax() {
        let response = AssistantResponseText(text: #"\[\boxed{x=-2}\] and \[\fbox{x=-3}\]"#)

        XCTAssertEqual(
            response.renderableText,
            #"\[\enclose{box}{x=-2}\] and \[\enclose{box}{x=-3}\]"#
        )
    }

    func testGlobalShortcutIsOptionSpace() {
        XCTAssertEqual(GlobalHotKey.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(GlobalHotKey.modifiers, UInt32(optionKey))
    }

    func testTaskShortcutIsOptionCommandSpace() {
        XCTAssertEqual(GlobalHotKey.taskModifiers, UInt32(optionKey | cmdKey))
        XCTAssertTrue(GlobalHotKey.shouldHandle(eventID: 2, registeredID: 2))
        XCTAssertFalse(GlobalHotKey.shouldHandle(eventID: 1, registeredID: 2))
    }

    @MainActor
    func testTaskManagerDefaultsToListView() {
        let view = TaskManagerView(model: AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil)
        ))
        let state = Mirror(reflecting: view).children
            .first { $0.label == "_viewMode" }?.value as? State<TaskViewMode>

        guard let state else {
            return XCTFail("Missing task view mode state")
        }
        guard case .list = state.wrappedValue else {
            return XCTFail("Task manager should open in list view")
        }
    }

    func testAppStaysMenuBarOnly() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool, true)
    }

    @MainActor
    func testUnexpectedTerminationIsCancelledForMenuBarOnlyApp() {
        let delegate = AppDelegate()

        XCTAssertEqual(delegate.applicationShouldTerminate(NSApp), .terminateCancel)
        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp))
    }

    @MainActor
    func testOverlayPositionRoundTrip() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let origin = NSPoint(x: -420.5, y: 180.25)

        OverlayPanelController.saveOrigin(origin, in: defaults)

        XCTAssertEqual(OverlayPanelController.savedOrigin(in: defaults), origin)
    }

    @MainActor
    func testOverlayOpensOnPointerDisplayWhenFocusIsEnabled() throws {
        let settings = AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let controller = OverlayPanelController(model: AppModel(
            settings: settings,
            taskStore: TaskStore(fileURL: nil, calendarSync: nil)
        ))
        let screen = try XCTUnwrap(
            NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
                ?? NSScreen.main
        )

        controller.show()
        defer { controller.hide() }
        let panel = try XCTUnwrap(NSApp.keyWindow as? KeyablePanel)

        XCTAssertTrue(screen.visibleFrame.contains(panel.frame))
    }

    @MainActor
    func testOverlayMovesToAnotherDisplayWhenFocusChanges() {
        let firstDisplay = NSRect(x: 0, y: 0, width: 1600, height: 900)
        let secondDisplay = NSRect(x: 1600, y: 0, width: 1600, height: 900)
        let panelSize = NSSize(width: OverlayLayout.collapsedWidth, height: OverlayLayout.collapsedHeight)
        let previousOrigin = NSPoint(x: 520, y: 64)

        XCTAssertEqual(
            OverlayPanelController.origin(
                on: secondDisplay,
                panelSize: panelSize,
                previousOrigin: previousOrigin
            ),
            NSPoint(x: 2240, y: 64)
        )
        XCTAssertEqual(
            OverlayPanelController.origin(
                on: firstDisplay,
                panelSize: panelSize,
                previousOrigin: previousOrigin
            ),
            previousOrigin
        )
    }

    @MainActor
    func testOverlayResizeGeometry() {
        let frame = NSRect(x: 100, y: 100, width: 560, height: 590)
        let screen = NSRect(x: 0, y: 0, width: 1200, height: 900)

        XCTAssertEqual(
            OverlayPanelController.resizedFrame(frame, handle: .left,
                                                translation: CGSize(width: 50, height: 0), within: screen),
            NSRect(x: 150, y: 100, width: 510, height: 590)
        )
        XCTAssertEqual(
            OverlayPanelController.resizedFrame(frame, handle: .right,
                                                translation: CGSize(width: 100, height: 0), within: screen),
            NSRect(x: 100, y: 100, width: 660, height: 590)
        )
        XCTAssertEqual(
            OverlayPanelController.resizedFrame(frame, handle: .topLeft,
                                                translation: CGSize(width: 50, height: -80), within: screen),
            NSRect(x: 150, y: 100, width: 510, height: 670)
        )
        XCTAssertEqual(
            OverlayPanelController.resizedFrame(frame, handle: .bottomRight,
                                                translation: CGSize(width: 100, height: -120), within: screen),
            NSRect(x: 100, y: 220, width: 660, height: 470)
        )
        XCTAssertEqual(
            OverlayPanelController.resizedFrame(frame, handle: .bottomLeft,
                                                translation: CGSize(width: 900, height: 900), within: screen),
            NSRect(x: 340, y: 12, width: 320, height: 678)
        )
        XCTAssertEqual(
            OverlayPanelController.resizedFrame(frame, handle: .topRight,
                                                translation: CGSize(width: 900, height: 900), within: screen),
            NSRect(x: 100, y: 100, width: 1088, height: 300)
        )
    }

    @MainActor
    func testOverlayResizeTracksScreenPointerWithoutFeedback() throws {
        let existingPanels = Set(NSApp.windows.compactMap { $0 as? KeyablePanel }.map { ObjectIdentifier($0) })
        let model = AppModel(
            settings: AppSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            mockResponse: "Response"
        )
        let controller = OverlayPanelController(model: model)
        model.prompt = "Question"
        model.submit()
        controller.show()
        defer { controller.hide() }

        let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? KeyablePanel }
            .first { !existingPanels.contains(ObjectIdentifier($0)) })
        let original = panel.frame
        XCTAssertEqual(original.width, CGFloat(OverlayLayout.collapsedWidth))
        XCTAssertEqual(original.height, CGFloat(OverlayLayout.expandedHeight))
        let local = CGPoint(x: 4, y: original.height / 2)
        controller.resize(.left, at: local)
        controller.resize(.left, at: CGPoint(x: local.x - 45, y: local.y))
        let resized = panel.frame

        XCTAssertEqual(resized.maxX, original.maxX)
        XCTAssertEqual(resized.width, original.width + 45)
        controller.resize(.left, at: local)
        XCTAssertEqual(panel.frame, resized)
    }

    @MainActor
    func testHistoryRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let fileURL = directory.appending(path: "history.json")
        let message = ChatMessage(role: .user, text: "Explain this code")
        let conversation = Conversation(title: "SwiftUI Overlay", messages: [message])

        let store = ChatHistoryStore(fileURL: fileURL)
        store.upsert(conversation)
        let reloaded = ChatHistoryStore(fileURL: fileURL)

        XCTAssertEqual(reloaded.conversations, [conversation])
        let json = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(json.contains("imageData"))
        XCTAssertFalse(json.contains("ocrText"))
    }

    func testConversationTitleCleanup() {
        XCTAssertEqual(
            Conversation.cleanedTitle("\"SwiftUI overlay corners\"", fallbackPrompt: "Explain this"),
            "SwiftUI overlay corners"
        )
        XCTAssertEqual(
            Conversation.cleanedTitle("", fallbackPrompt: "Explain why this SwiftUI overlay has corners today"),
            "Explain why this SwiftUI overlay has"
        )
    }

    @MainActor
    func testOverlayPanelTogglesPresentedState() {
        let existingPanels = Set(NSApp.windows.compactMap { $0 as? KeyablePanel }.map { ObjectIdentifier($0) })
        let controller = OverlayPanelController(model: AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil)
        ))

        XCTAssertFalse(controller.isPresented)
        controller.toggle()
        XCTAssertTrue(controller.isPresented)
        XCTAssertEqual(
            NSApp.windows.compactMap { $0 as? KeyablePanel }
                .first { !existingPanels.contains(ObjectIdentifier($0)) }?.frame.width,
            CGFloat(OverlayLayout.collapsedWidth)
        )
        controller.toggle()
        XCTAssertFalse(controller.isPresented)
    }

    @MainActor
    func testTaskScreenKeepsFullWidthAndNewChatReturnsToCompactBar() throws {
        let existingPanels = Set(NSApp.windows.compactMap { $0 as? KeyablePanel }.map { ObjectIdentifier($0) })
        let controller = OverlayPanelController(model: AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil)
        ))

        controller.showTasks()
        RunLoop.main.run(until: Date().addingTimeInterval(0.7))
        let panel = try XCTUnwrap(NSApp.windows.compactMap { $0 as? KeyablePanel }
            .first { !existingPanels.contains(ObjectIdentifier($0)) })
        XCTAssertEqual(panel.frame.width, CGFloat(OverlayLayout.width))

        controller.startNewChat()
        RunLoop.main.run(until: Date().addingTimeInterval(0.7))
        XCTAssertEqual(panel.frame.width, CGFloat(OverlayLayout.collapsedWidth))
        controller.hide()
    }

    @MainActor
    func testHiddenConversationResumesWithinGraceAndExpiresAfterGrace() async {
        let model = AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            mockResponse: "Answer",
            conversationGracePeriod: 2
        )
        let controller = OverlayPanelController(model: model)

        controller.show()
        model.prompt = "Keep this chat"
        model.submit()
        let suspendedID = model.conversation.id
        model.toggleScreenshotForNextMessage()
        controller.hide()

        controller.show()
        XCTAssertEqual(model.conversation.id, suspendedID)
        XCTAssertFalse(model.includeScreenshotForNextMessage)

        controller.hide()
        try? await Task.sleep(for: .seconds(2.1))
        controller.show()
        XCTAssertNotEqual(model.conversation.id, suspendedID)
        XCTAssertTrue(model.includeScreenshotForNextMessage)
    }

    @MainActor
    func testAppRuntimeStartsWithOverlayHidden() {
        let runtime = AppRuntime(taskStore: TaskStore(fileURL: nil, calendarSync: nil))
        runtime.start()

        XCTAssertFalse(runtime.isOverlayPresented)
    }

    func testLoginItemRegistrationHandlesMissingService() {
        XCTAssertTrue(AppRuntime.shouldRegisterLoginItem(status: .notRegistered))
        XCTAssertTrue(AppRuntime.shouldRegisterLoginItem(status: .notFound))
        XCTAssertFalse(AppRuntime.shouldRegisterLoginItem(status: .enabled))
        XCTAssertFalse(AppRuntime.shouldRegisterLoginItem(status: .requiresApproval))
    }

    @MainActor
    func testStartingNewConversationClearsTransientState() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "history.json")
        let model = AppModel(
            settings: AppSettings(),
            history: ChatHistoryStore(fileURL: fileURL),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil)
        )
        model.prompt = "Draft"
        model.conversation = Conversation(
            title: "Old topic",
            messages: [ChatMessage(role: .assistant, text: "Old answer")]
        )
        model.streamingResponse = "Partial"
        model.errorMessage = "Error"
        model.attachedScreenshot = Data([1, 2, 3])

        model.startNewConversation()

        XCTAssertEqual(model.prompt, "")
        XCTAssertEqual(model.conversation.title, "New Chat")
        XCTAssertTrue(model.conversation.messages.isEmpty)
        XCTAssertEqual(model.streamingResponse, "")
        XCTAssertEqual(model.errorMessage, "")
        XCTAssertNil(model.attachedScreenshot)
    }

    @MainActor
    func testMockResponseBypassesProviderAndScreenCapture() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let model = AppModel(
            settings: AppSettings(defaults: defaults),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            mockResponse: "**Answer:** The closure captures `count`."
        )
        model.prompt = "Explain this code"

        model.submit()

        XCTAssertEqual(model.conversation.messages.count, 2)
        XCTAssertEqual(model.conversation.messages.first?.role.rawValue, "user")
        XCTAssertEqual(model.conversation.messages.last?.role.rawValue, "assistant")
        XCTAssertEqual(model.conversation.messages.last?.text, "**Answer:** The closure captures `count`.")
        XCTAssertFalse(model.isWorking)
        XCTAssertEqual(model.errorMessage, "")
    }

    func testScreenshotSelectionAlwaysIncludesFirstRequest() {
        XCTAssertTrue(AppModel.shouldIncludeScreenshot(
            hasCompletedFirstResponse: false,
            includeScreenshotForNextMessage: false
        ))
        XCTAssertTrue(AppModel.shouldIncludeScreenshot(
            hasCompletedFirstResponse: true,
            includeScreenshotForNextMessage: true
        ))
        XCTAssertFalse(AppModel.shouldIncludeScreenshot(
            hasCompletedFirstResponse: true,
            includeScreenshotForNextMessage: false
        ))
    }

    @MainActor
    func testScreenshotToggleIsLockedUntilFirstResponseAndResetsForNewChat() {
        let model = AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            mockResponse: "Answer"
        )

        XCTAssertTrue(model.includeScreenshotForNextMessage)
        model.toggleScreenshotForNextMessage()
        XCTAssertTrue(model.includeScreenshotForNextMessage)

        model.prompt = "First question"
        model.submit()
        XCTAssertTrue(model.canToggleScreenshot)

        model.toggleScreenshotForNextMessage()
        XCTAssertFalse(model.includeScreenshotForNextMessage)
        model.startNewConversation()
        XCTAssertTrue(model.includeScreenshotForNextMessage)
    }

    func testOpenAIPayloadDisablesStorageAndIncludesBothContexts() throws {
        let messages = [
            ChatMessage(role: .user, text: "What does this function do?"),
            ChatMessage(role: .assistant, text: "It parses a response."),
            ChatMessage(role: .user, text: "Explain the selected line")
        ]
        let body = ProviderRequestBuilder.requestBody(
            provider: .openAI,
            model: "gpt-4.1-mini",
            messages: messages,
            ocrText: "What is 2 + 2?",
            imageData: Data([1, 2, 3])
        )

        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: body).count > 0)
        let json = String(data: try JSONSerialization.data(withJSONObject: body), encoding: .utf8)!
        XCTAssertTrue(json.contains("What is 2 + 2?"))
        XCTAssertTrue(json.contains("It parses a response."))
        let input = body["input"] as? [[String: Any]]
        let content = input?.first?["content"] as? [[String: Any]]
        let imageURL = content?.last?["image_url"] as? String
        XCTAssertTrue(imageURL?.hasPrefix("data:image/jpeg;base64,") == true)

        let titleBody = ProviderRequestBuilder.requestBody(
            provider: .openAI,
            model: "gpt-4.1-mini",
            messages: [ChatMessage(role: .user, text: "Generate a short title")]
        )
        let titleJSON = String(data: try JSONSerialization.data(withJSONObject: titleBody), encoding: .utf8)!
        XCTAssertFalse(titleJSON.contains("data:image"))
    }

    func testSSEDecoderReadsProviderDeltas() {
        let openAI = #"{"type":"response.output_text.delta","delta":"Hello"}"#
        let openRouter = #"{"choices":[{"delta":{"content":"World"}}]}"#

        XCTAssertEqual(SSEDecoder.delta(from: openAI, provider: .openAI), "Hello")
        XCTAssertEqual(SSEDecoder.delta(from: openRouter, provider: .openRouter), "World")
        XCTAssertNil(SSEDecoder.delta(from: "[DONE]", provider: .openAI))
    }

    func testStreamingDeltaBufferCoalescesRapidUpdatesWithoutLosingText() {
        let clock = ContinuousClock()
        let start = clock.now
        var buffer = StreamingDeltaBuffer(now: start)

        XCTAssertNil(buffer.append("Hel", now: start))
        XCTAssertNil(buffer.append("lo", now: start.advanced(by: .milliseconds(49))))
        XCTAssertEqual(
            buffer.append("!", now: start.advanced(by: .milliseconds(50))),
            "Hello!"
        )
        XCTAssertNil(buffer.append(" Bye", now: start.advanced(by: .milliseconds(51))))
        XCTAssertEqual(buffer.flush(), " Bye")
        XCTAssertNil(buffer.flush())
    }

    func testTaskParserReadsSampleNaturalLanguageEntry() throws {
        let task = try TaskEntryParser.parse(
            "phys homework unit 3 due on next tue",
            now: date(2026, 8, 13),
            calendar: utcCalendar
        )

        XCTAssertEqual(task.title, "phys homework unit 3")
        XCTAssertEqual(task.dueDate, date(2026, 8, 18))
    }

    func testTaskParserReadsRelativeAndISODateEntries() throws {
        let tomorrow = try TaskEntryParser.parse(
            "Submit essay due tomorrow",
            now: date(2026, 8, 13),
            calendar: utcCalendar
        )
        let iso = try TaskEntryParser.parse(
            "Return books by 2026-08-20",
            now: date(2026, 8, 13),
            calendar: utcCalendar
        )

        XCTAssertEqual(tomorrow.dueDate, date(2026, 8, 14))
        XCTAssertEqual(iso.dueDate, date(2026, 8, 20))
    }

    func testTaskParserAcceptsUndatedEntryAndRejectsInvalidDuePhrase() throws {
        let task = try TaskEntryParser.parse("Buy lab notebook")

        XCTAssertEqual(task.title, "Buy lab notebook")
        XCTAssertNil(task.dueDate)
        XCTAssertThrowsError(try TaskEntryParser.parse("Essay due eventually"))
        XCTAssertThrowsError(try TaskEntryParser.parse("Essay due 2026-08-20-extra"))
        XCTAssertThrowsError(try TaskEntryParser.parse("Essay due 999999999999999999999999-08-20"))
    }

    func testFoundationModelOutputBuildsValidatedTask() throws {
        let dueDateText = "2026-08-18T14:30:00+07:00"
        let task = try FoundationModelTaskParser.makeTask(
            title: "  Physics homework  ",
            dueDateISO8601: dueDateText,
            notes: "  Unit 3  ",
            createdAt: date(2026, 8, 13)
        )

        XCTAssertEqual(task.title, "Physics homework")
        XCTAssertEqual(task.dueDate, ISO8601DateFormatter().date(from: dueDateText))
        XCTAssertEqual(task.notes, "Unit 3")
        XCTAssertEqual(task.createdAt, date(2026, 8, 13))
        let fractionalDateTask = try FoundationModelTaskParser.makeTask(
            title: "Physics homework",
            dueDateISO8601: "2026-08-18T14:30:00.500+07:00",
            notes: ""
        )
        XCTAssertEqual(
            try XCTUnwrap(fractionalDateTask.dueDate).timeIntervalSince1970,
            try XCTUnwrap(task.dueDate).timeIntervalSince1970 + 0.5,
            accuracy: 0.001
        )
        XCTAssertThrowsError(try FoundationModelTaskParser.makeTask(
            title: "  ",
            dueDateISO8601: nil,
            notes: ""
        ))
        XCTAssertThrowsError(try FoundationModelTaskParser.makeTask(
            title: "Physics",
            dueDateISO8601: "next whenever",
            notes: ""
        ))
    }

    func testFoundationModelParserHonorsExplicitTaskDateSuffix() throws {
        let generated = ScreenieTask(
            title: "Physics deadline",
            dueDate: date(2026, 8, 17),
            notes: "Next Tuesday"
        )

        let corrected = FoundationModelTaskParser.reconcileDueDate(
            in: generated,
            entry: "physics deadline next tue",
            now: date(2026, 8, 13, 20),
            calendar: utcCalendar
        )

        XCTAssertEqual(corrected.dueDate, date(2026, 8, 18))
        XCTAssertEqual(corrected.title, generated.title)
        XCTAssertEqual(corrected.notes, generated.notes)
        XCTAssertEqual(
            FoundationModelTaskParser.reconcileDueDate(
                in: generated,
                entry: "physics deadline after class",
                now: date(2026, 8, 13, 20),
                calendar: utcCalendar
            ).dueDate,
            generated.dueDate
        )
    }

    @MainActor
    func testTaskStoreSortsDueDatesBeforeUndatedTasksAndTogglesCompletion() {
        let store = TaskStore(fileURL: nil, calendarSync: nil)
        let undated = ScreenieTask(title: "Undated")
        let later = ScreenieTask(title: "Later", dueDate: date(2026, 8, 20))
        let sooner = ScreenieTask(title: "Sooner", dueDate: date(2026, 8, 14))

        store.add(undated)
        store.add(later)
        store.add(sooner)
        store.toggleCompletion(of: sooner.id)

        XCTAssertEqual(store.sortedTasks.map(\.title), ["Sooner", "Later", "Undated"])
        XCTAssertTrue(store.sortedTasks[0].isCompleted)
    }

    @MainActor
    func testTaskStorePersistsCompletionAndRestoration() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "tasks.json")
        let createdAt = date(2026, 8, 13)
        let completedAt = date(2026, 8, 14)
        let task = ScreenieTask(
            title: "Physics",
            dueDate: date(2026, 8, 18),
            notes: "Unit 3",
            createdAt: createdAt
        )
        let store = TaskStore(fileURL: fileURL, calendarSync: nil)

        store.add(task)
        XCTAssertEqual(TaskStore(fileURL: fileURL, calendarSync: nil).tasks, [task])

        store.toggleCompletion(of: task.id, at: completedAt)
        let completed = try XCTUnwrap(TaskStore(fileURL: fileURL, calendarSync: nil).tasks.first)
        XCTAssertTrue(completed.isCompleted)
        XCTAssertEqual(completed.completedAt, completedAt)

        store.toggleCompletion(of: task.id, at: date(2026, 8, 15))
        let restored = try XCTUnwrap(TaskStore(fileURL: fileURL, calendarSync: nil).tasks.first)
        XCTAssertFalse(restored.isCompleted)
        XCTAssertNil(restored.completedAt)

        let json = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(json.contains("imageData"))
        XCTAssertFalse(json.contains("ocrText"))
        XCTAssertFalse(json.contains("taskSchedule"))
    }

    @MainActor
    func testTaskStorePersistsDeletionAndRemovesCalendarEvent() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "tasks.json")
        let task = ScreenieTask(
            title: "Accidental task",
            dueDate: date(2026, 8, 18),
            calendarEventIdentifier: "event-123"
        )
        var deletedTask: ScreenieTask?
        let store = TaskStore(
            fileURL: fileURL,
            calendarDelete: { deletedTask = $0 },
            calendarSync: nil
        )

        store.add(task)
        store.delete(task.id)
        await waitUntil { deletedTask != nil }

        XCTAssertEqual(deletedTask, task)
        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertTrue(TaskStore(fileURL: fileURL, calendarSync: nil).tasks.isEmpty)
    }

    @MainActor
    func testTaskStoreChangesAndRemovesDeadline() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "tasks.json")
        let originalDate = date(2026, 8, 18, 10)
        let changedDate = date(2026, 8, 20, 14)
        let task = ScreenieTask(title: "Physics", dueDate: originalDate)
        var synchronizedTasks: [ScreenieTask] = []
        var deletedTask: ScreenieTask?
        let store = TaskStore(
            fileURL: fileURL,
            calendarDelete: { deletedTask = $0 },
            calendarSync: { synchronizedTask in
                synchronizedTasks.append(synchronizedTask)
                return "event-123"
            }
        )

        store.add(task)
        await waitUntil { store.tasks.first?.calendarEventIdentifier == "event-123" }

        store.updateDueDate(of: task.id, to: changedDate)
        await waitUntil { synchronizedTasks.last?.dueDate == changedDate }
        XCTAssertEqual(store.tasks.first?.dueDate, changedDate)
        XCTAssertEqual(TaskStore(fileURL: fileURL, calendarSync: nil).tasks.first?.dueDate, changedDate)

        store.updateDueDate(of: task.id, to: nil)
        await waitUntil { deletedTask != nil }

        XCTAssertEqual(deletedTask?.dueDate, changedDate)
        XCTAssertEqual(deletedTask?.calendarEventIdentifier, "event-123")
        XCTAssertNil(store.tasks.first?.dueDate)
        XCTAssertNil(store.tasks.first?.calendarEventIdentifier)
        let persisted = try XCTUnwrap(TaskStore(fileURL: fileURL, calendarSync: nil).tasks.first)
        XCTAssertNil(persisted.dueDate)
        XCTAssertNil(persisted.calendarEventIdentifier)
    }

    @MainActor
    func testTaskStoreKeepsCorruptFileAndOrdersCompletedTasksNewestFirst() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "tasks.json")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: fileURL)

        let corruptStore = TaskStore(fileURL: fileURL, calendarSync: nil)

        XCTAssertTrue(corruptStore.tasks.isEmpty)
        XCTAssertTrue(corruptStore.lastError.contains("Could not load tasks"))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "not json")

        let store = TaskStore(fileURL: nil, calendarSync: nil)
        let older = ScreenieTask(
            title: "Older",
            isCompleted: true,
            createdAt: date(2026, 8, 10),
            completedAt: date(2026, 8, 11)
        )
        let newer = ScreenieTask(
            title: "Newer",
            isCompleted: true,
            createdAt: date(2026, 8, 12),
            completedAt: date(2026, 8, 13)
        )
        store.add(older)
        store.add(newer)

        XCTAssertEqual(store.completedTasks.map(\.title), ["Newer", "Older"])
    }

    func testTaskCalendarEventMapping() {
        let task = ScreenieTask(
            title: "Physics",
            dueDate: date(2026, 8, 18),
            notes: "Unit 3",
            isCompleted: true
        )

        let event = TaskCalendarEvent(task: task)

        XCTAssertEqual(event.title, "✓ Physics")
        XCTAssertEqual(event.startDate, date(2026, 8, 18))
        XCTAssertEqual(event.endDate, date(2026, 8, 18).addingTimeInterval(30 * 60))
        XCTAssertEqual(
            event.notes,
            "Unit 3\n\nManaged by screenie\nTask ID: \(task.id.uuidString)"
        )
        XCTAssertEqual(event.taskMarker, "Task ID: \(task.id.uuidString)")
    }

    @MainActor
    func testTaskCalendarBuildsLocaleAwareMonthAndWeekRanges() {
        var calendar = utcCalendar
        calendar.firstWeekday = 2

        let month = TaskCalendarView.monthDates(
            containing: date(2026, 8, 13),
            calendar: calendar
        )
        let week = TaskCalendarView.weekDates(
            containing: date(2026, 8, 13),
            calendar: calendar
        )

        XCTAssertEqual(month.count, 42)
        XCTAssertEqual(month.first, date(2026, 7, 27, 0))
        XCTAssertEqual(month.last, date(2026, 9, 6, 0))
        XCTAssertEqual(week, (10...16).map { date(2026, 8, $0, 0) })
    }

    @MainActor
    func testTaskStoreRollsBackWhenPersistenceFails() {
        let store = TaskStore(
            fileURL: URL(filePath: "/dev/null/tasks.json"),
            calendarSync: nil
        )

        store.add(ScreenieTask(title: "Must not appear saved"))

        XCTAssertTrue(store.tasks.isEmpty)
        XCTAssertTrue(store.lastError.contains("Could not save tasks"))
        XCTAssertEqual(store.errorMessage, store.lastError)
    }

    @MainActor
    func testTaskStorePersistsCalendarEventIdentifierAfterSync() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "tasks.json")
        let task = ScreenieTask(title: "Physics", dueDate: date(2026, 8, 18))
        let store = TaskStore(fileURL: fileURL, calendarSync: { synchronizedTask in
            XCTAssertEqual(synchronizedTask.id, task.id)
            return "event-123"
        })

        store.add(task)
        await waitUntil { store.tasks.first?.calendarEventIdentifier == "event-123" }

        XCTAssertEqual(store.tasks.first?.calendarEventIdentifier, "event-123")
        XCTAssertEqual(
            TaskStore(fileURL: fileURL, calendarSync: nil).tasks.first?.calendarEventIdentifier,
            "event-123"
        )
    }

    @MainActor
    func testTaskStoreRetainsEachCalendarSyncErrorUntilThatTaskSucceeds() async {
        let failed = ScreenieTask(title: "Fails", dueDate: date(2026, 8, 18))
        let succeeds = ScreenieTask(title: "Succeeds", dueDate: date(2026, 8, 19))
        let store = TaskStore(fileURL: nil, calendarSync: { task in
            guard task.id != failed.id else {
                throw NSError(
                    domain: "calendar-test",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Intentional failure"]
                )
            }
            return "event-\(task.id)"
        })

        store.add(failed)
        store.add(succeeds)
        await waitUntil {
            store.tasks.first(where: { $0.id == succeeds.id })?.calendarEventIdentifier != nil
                && !store.calendarError(for: failed.id).isEmpty
        }

        XCTAssertTrue(store.calendarError(for: failed.id).contains("Intentional failure"))
        XCTAssertTrue(store.calendarError(for: succeeds.id).isEmpty)
        XCTAssertFalse(store.calendarError.isEmpty)
    }

    @MainActor
    func testTaskCommandOpensTaskModeWithoutAPIKeyOrCapture() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let model = AppModel(
            settings: AppSettings(defaults: defaults),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil)
        )
        model.prompt = "/task"

        model.submit()

        XCTAssertEqual(model.presentationMode, .tasks)
        XCTAssertEqual(model.prompt, "")
        XCTAssertEqual(model.errorMessage, "")
        XCTAssertTrue(model.taskStore.tasks.isEmpty)
    }

    @MainActor
    func testTaskCommandAddsAsyncNaturalLanguageTask() async {
        let parsedTask = ScreenieTask(
            title: "Plan revision",
            dueDate: date(2026, 8, 13, 11)
        )
        let model = AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            taskParser: { entry in
                XCTAssertEqual(entry, "plan revision in two hours")
                try await Task.sleep(for: .milliseconds(1))
                return parsedTask
            }
        )
        model.prompt = "/task plan revision in two hours"

        model.submit()

        XCTAssertEqual(model.presentationMode, .tasks)
        XCTAssertTrue(model.isParsingTask)
        await waitUntil { !model.isParsingTask }
        XCTAssertEqual(model.taskStore.tasks, [parsedTask])
    }

    @MainActor
    func testTaskCommandShowsInvalidDueDateInline() async {
        let model = AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            taskParser: { _ in
                throw TaskEntryParserError.invalidDueDate("eventually")
            }
        )
        model.prompt = "/task essay due eventually"

        model.submit()

        XCTAssertEqual(model.presentationMode, .tasks)
        await waitUntil { !model.isParsingTask }
        XCTAssertTrue(model.taskError.contains("eventually"))
        XCTAssertTrue(model.taskStore.tasks.isEmpty)
    }

    @MainActor
    func testLeavingTaskModeCancelsPendingTaskCreation() async {
        let model = AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            taskParser: { _ in
                try await Task.sleep(for: .milliseconds(30))
                return ScreenieTask(title: "Must not be added")
            }
        )
        model.prompt = "/task cancel me"

        model.submit()
        model.presentChat()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(model.presentationMode, .chat)
        XCTAssertFalse(model.isParsingTask)
        XCTAssertTrue(model.taskStore.tasks.isEmpty)
    }

    @MainActor
    func testReplacingTaskParseKeepsNewestProgressAndResult() async {
        let model = AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            taskParser: { entry in
                if entry == "first" {
                    try? await Task.sleep(for: .milliseconds(5))
                    return ScreenieTask(title: "Stale")
                }
                try await Task.sleep(for: .milliseconds(40))
                return ScreenieTask(title: "Newest")
            }
        )
        model.prompt = "/task first"
        model.submit()
        model.prompt = "/task second"
        model.submit()

        try? await Task.sleep(for: .milliseconds(15))
        XCTAssertTrue(model.isParsingTask)
        await waitUntil { !model.isParsingTask }
        XCTAssertEqual(model.taskStore.tasks.map(\.title), ["Newest"])
    }

    func testTaskScheduleRequestUsesStrictJSONSchemaAndIncompleteTasks() throws {
        let tasks = [
            ScreenieTask(title: "Physics", dueDate: date(2026, 8, 18)),
            ScreenieTask(title: "Finished", isCompleted: true)
        ]
        let body = ProviderRequestBuilder.taskScheduleRequestBody(
            model: "openai/gpt-5.6-luna",
            tasks: tasks,
            now: date(2026, 8, 13),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        let json = String(data: try JSONSerialization.data(withJSONObject: body), encoding: .utf8)!

        XCTAssertEqual(body["stream"] as? Bool, false)
        XCTAssertTrue(json.contains("json_schema"))
        XCTAssertTrue(json.contains("additionalProperties"))
        XCTAssertTrue(json.contains("require_parameters"))
        XCTAssertTrue(json.contains("Monday: Period 4 (10:45-11:30)"))
        XCTAssertTrue(json.contains("Physics"))
        XCTAssertFalse(json.contains("Finished"))
    }

    func testTaskScheduleDecodesOpenRouterResponse() throws {
        let content = #"{"summary":"Use two study periods.","suggestions":[{"taskTitle":"Physics","start":"2026-08-17T10:45:00Z","end":"2026-08-17T11:30:00Z","note":"Start with unit 3."}]}"#
        let outer = try JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": content]]]
        ])

        let schedule = try TaskSchedule.decodeOpenRouterResponse(outer)

        XCTAssertEqual(schedule.summary, "Use two study periods.")
        XCTAssertEqual(schedule.suggestions.first?.taskTitle, "Physics")
        XCTAssertEqual(
            schedule.suggestions.first?.start,
            utcCalendar.date(from: DateComponents(year: 2026, month: 8, day: 17, hour: 10, minute: 45))
        )
    }

    func testTaskScheduleCalendarEventMapping() {
        let suggestion = TaskScheduleSuggestion(
            taskTitle: "Physics",
            start: date(2026, 8, 17, 10),
            end: date(2026, 8, 17, 11),
            note: "Review unit 3."
        )

        let event = TaskScheduleCalendarEvent(suggestion: suggestion)

        XCTAssertEqual(event.title, "Study: Physics")
        XCTAssertEqual(event.startDate, suggestion.start)
        XCTAssertEqual(event.endDate, suggestion.end)
        XCTAssertEqual(
            event.notes,
            "Review unit 3.\n\nSuggested by screenie\n\(event.marker)"
        )
        XCTAssertEqual(event.marker, "Schedule suggestion: \(suggestion.id)")
    }

    @MainActor
    func testAppModelDismissesTaskSchedule() {
        let model = AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil)
        )
        model.taskSchedule = TaskSchedule(summary: "Study tonight.", suggestions: [])

        model.dismissTaskSchedule()

        XCTAssertNil(model.taskSchedule)
        XCTAssertFalse(model.didAddTaskScheduleToCalendar)
    }

    @MainActor
    func testAppModelAddsTaskScheduleToCalendar() async {
        let schedule = TaskSchedule(summary: "Study tonight.", suggestions: [
            TaskScheduleSuggestion(
                taskTitle: "Physics",
                start: date(2026, 8, 17, 10),
                end: date(2026, 8, 17, 11),
                note: "Review unit 3."
            )
        ])
        var addedSchedule: TaskSchedule?
        let model = AppModel(
            settings: AppSettings(),
            taskStore: TaskStore(fileURL: nil, calendarSync: nil),
            taskScheduleCalendarSync: { addedSchedule = $0 }
        )
        model.taskSchedule = schedule

        model.addTaskScheduleToCalendar()
        await waitUntil { !model.isAddingTaskScheduleToCalendar }

        XCTAssertEqual(addedSchedule, schedule)
        XCTAssertTrue(model.didAddTaskScheduleToCalendar)
        XCTAssertEqual(model.taskError, "")
    }

    func testTaskScheduleRejectsBackwardTimeRange() throws {
        let content = #"{"summary":"Invalid.","suggestions":[{"taskTitle":"Physics","start":"2026-08-17T11:30:00Z","end":"2026-08-17T10:45:00Z","note":"Wrong order."}]}"#
        let outer = try JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": content]]]
        ])

        XCTAssertThrowsError(try TaskSchedule.decodeOpenRouterResponse(outer))
    }

    func testTaskScheduleRejectsUnknownJSONProperties() {
        let content = #"{"summary":"No extras.","unexpected":true,"suggestions":[]}"#.data(using: .utf8)!

        XCTAssertThrowsError(try TaskSchedule.decodeContent(content))
    }

    @MainActor
    func testSettingsCanReadSavedOpenRouterKeyWhenOpenAIIsSelected() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.apiKey = "router-key"
        settings.saveAPIKey()
        settings.provider = .openAI

        XCTAssertEqual(settings.apiKey(for: .openRouter), "router-key")
    }

    private func containsAssistantResponseText(in value: Any, depth: Int = 0) -> Bool {
        guard depth < 20 else { return false }
        if value is AssistantResponseText { return true }
        return Mirror(reflecting: value).children.contains {
            containsAssistantResponseText(in: $0.value, depth: depth + 1)
        }
    }
}
