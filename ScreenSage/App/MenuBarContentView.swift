import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("New Chat", systemImage: "sparkles", action: AppRuntime.shared.showOverlay)
        Button("History", systemImage: "clock.arrow.circlepath") {
            openWindow(id: "history")
            NSApp.activate(ignoringOtherApps: true)
        }
        SettingsLink { Text("Settings…") }
        Divider()
        Button("Quit screenie") { NSApp.terminate(nil) }
    }
}
