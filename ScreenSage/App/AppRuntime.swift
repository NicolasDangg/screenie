import AppKit
import ServiceManagement

@MainActor
final class AppRuntime {
    static let shared: AppRuntime = {
        guard NSClassFromString("XCTestCase") == nil else {
            return AppRuntime(
                history: ChatHistoryStore(fileURL: FileManager.default.temporaryDirectory
                    .appending(path: UUID().uuidString)
                    .appending(path: "history.json")),
                taskStore: TaskStore(fileURL: nil, calendarSync: nil)
            )
        }
        return AppRuntime()
    }()

    let settings: AppSettings
    let history: ChatHistoryStore
    private let taskStore: TaskStore
    lazy var model = AppModel(settings: settings, history: history, taskStore: taskStore)
    private lazy var panelController = OverlayPanelController(model: model)
    private var hotKey: GlobalHotKey?
    private var taskHotKey: GlobalHotKey?

    init(
        settings: AppSettings = AppSettings(),
        history: ChatHistoryStore = ChatHistoryStore(),
        taskStore: TaskStore = TaskStore()
    ) {
        self.settings = settings
        self.history = history
        self.taskStore = taskStore
    }

    var isOverlayPresented: Bool { panelController.isPresented }

    nonisolated static func shouldRegisterLoginItem(status: SMAppService.Status) -> Bool {
        status == .notRegistered || status == .notFound
    }

    func start() {
        hotKey = GlobalHotKey { [weak self] in self?.toggleOverlay() }
        taskHotKey = GlobalHotKey(modifiers: GlobalHotKey.taskModifiers, id: 2) { [weak self] in
            self?.panelController.toggleTaskScreen()
        }
        if ProcessInfo.processInfo.environment["SCREENIE_OPEN_TASKS"] == "1" {
            panelController.showTasks()
        }
        if Bundle.main.bundleURL.path.hasPrefix("/Applications/"),
           Self.shouldRegisterLoginItem(status: SMAppService.mainApp.status) {
            try? SMAppService.mainApp.register()
        }
    }

    func showOverlay() {
        panelController.startNewChat()
    }

    func toggleOverlay() {
        if panelController.isPresented {
            panelController.hide()
        } else {
            panelController.show()
        }
    }
}
