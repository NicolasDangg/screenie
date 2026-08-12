import SwiftUI

@main
struct ScreenSageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Screen Sage", systemImage: "sparkles.rectangle.stack") {
            Button("Ask Screen", systemImage: "sparkles", action: AppRuntime.shared.showOverlay)
            SettingsLink { Text("Settings…") }
            Divider()
            Button("Quit Screen Sage") { NSApp.terminate(nil) }
        }
        Settings { SettingsView(settings: AppRuntime.shared.settings) }
    }
}
