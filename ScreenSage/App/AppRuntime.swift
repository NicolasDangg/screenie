import AppKit

@MainActor
final class AppRuntime {
    static let shared = AppRuntime()

    let settings = AppSettings()
    let history = ChatHistoryStore()
    lazy var model = AppModel(settings: settings, history: history)
    private lazy var panelController = OverlayPanelController(model: model)
    private var hotKey: GlobalHotKey?

    private init() {}

    func start() {
        hotKey = GlobalHotKey { [weak self] in self?.toggleOverlay() }
        showOverlay()
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
