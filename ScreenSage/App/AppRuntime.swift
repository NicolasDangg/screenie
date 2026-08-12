import AppKit
import ServiceManagement

@MainActor
final class AppRuntime {
    static let shared = AppRuntime()

    let settings = AppSettings()
    let history = ChatHistoryStore()
    lazy var model = AppModel(settings: settings, history: history)
    private lazy var panelController = OverlayPanelController(model: model)
    private var hotKey: GlobalHotKey?

    private init() {}

    var isOverlayPresented: Bool { panelController.isPresented }

    nonisolated static func shouldRegisterLoginItem(status: SMAppService.Status) -> Bool {
        status == .notRegistered || status == .notFound
    }

    func start() {
        hotKey = GlobalHotKey { [weak self] in self?.toggleOverlay() }
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
