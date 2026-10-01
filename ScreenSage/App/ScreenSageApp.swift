import SwiftUI

@main
struct ScreenSageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("screenie", systemImage: "sparkles.rectangle.stack") {
            MenuBarContentView()
        }
        Window("History", id: "history") {
            HistoryRootView(
                conversationStore: AppRuntime.shared.history,
                taskStore: AppRuntime.shared.model.taskStore
            )
        }
        .defaultSize(width: 720, height: 520)
        Settings {
            SettingsView(settings: AppRuntime.shared.settings, taskSources: AppRuntime.shared.model.taskSources)
        }
    }
}
