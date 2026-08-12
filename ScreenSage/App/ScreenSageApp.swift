import SwiftUI

@main
struct ScreenSageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("screenie", systemImage: "sparkles.rectangle.stack") {
            MenuBarContentView()
        }
        Window("History", id: "history") {
            HistoryView(store: AppRuntime.shared.history)
        }
        .defaultSize(width: 720, height: 520)
        Settings { SettingsView(settings: AppRuntime.shared.settings) }
    }
}
