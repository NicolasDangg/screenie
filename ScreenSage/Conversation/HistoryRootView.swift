import SwiftUI

struct HistoryRootView: View {
    @Bindable var conversationStore: ChatHistoryStore
    @Bindable var taskStore: TaskStore
    @State private var showsTasks = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("History type", selection: $showsTasks) {
                Text("Conversations").tag(false)
                Text("Tasks").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)
            .padding(10)

            Divider()

            if showsTasks {
                TaskHistoryView(store: taskStore)
            } else {
                HistoryView(store: conversationStore)
            }
        }
    }
}
