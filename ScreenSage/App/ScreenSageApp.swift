import SwiftUI

@main
struct ScreenSageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("screenie", systemImage: "sparkles.rectangle.stack") {
            MenuBarContentView(history: AppRuntime.shared.history)
        }
        Settings {
            SettingsView(settings: AppRuntime.shared.settings, taskSources: AppRuntime.shared.model.taskSources)
        }
    }
}
