import SwiftUI

struct HistoryRootView: View {
    @Bindable var conversationStore: ChatHistoryStore
    @Bindable var taskStore: TaskStore
    var continueConversation: (Conversation) -> Void = { _ in }
    @State private var showsTasks = false

    var body: some View {
        Group {
            if showsTasks {
                TaskHistoryView(store: taskStore)
            } else {
                HistoryView(store: conversationStore, continueConversation: continueConversation)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Show", selection: $showsTasks) {
                    Text("Chats").tag(false)
                    Text("Tasks").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}
