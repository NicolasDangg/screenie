import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @Bindable var history: ChatHistoryStore

    var body: some View {
        Button("Ask About Screen", action: AppRuntime.shared.showOverlay)
            .keyboardShortcut(" ", modifiers: .option)
        Button("Tasks", action: AppRuntime.shared.showTasks)
            .keyboardShortcut(" ", modifiers: [.option, .command])

        Divider()

        if !history.conversations.isEmpty {
            Section("Recent") {
                ForEach(history.conversations.prefix(3)) { conversation in
                    Button(conversation.title) {
                        AppRuntime.shared.continueConversation(conversation)
                    }
                }
            }
        }
        Button("All History…", action: AppRuntime.shared.showHistory)

        Divider()

        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Quit screenie") {
            AppDelegate.shared?.requestTermination()
        }
        .keyboardShortcut("q")
    }
}
