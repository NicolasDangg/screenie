import AppKit

@MainActor
final class AppRuntime {
    static let shared = AppRuntime()

    let settings = AppSettings()
    lazy var model = AppModel(settings: settings)
    private lazy var panelController = OverlayPanelController(model: model)
    private var hotKey: GlobalHotKey?

    private init() {}

    func start() {
        hotKey = GlobalHotKey { [weak self] in self?.toggleOverlay() }
        showOverlay()
    }

    func showOverlay() {
        model.prepareForPresentation()
        panelController.show()
    }

    func toggleOverlay() {
        if panelController.isPresented {
            panelController.hide()
        } else {
            model.prepareForPresentation()
            panelController.show()
        }
    }
}
