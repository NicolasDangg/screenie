import SwiftUI

struct HistoryView: View {
    @Bindable var store: ChatHistoryStore
    @State private var selection: Conversation.ID?

    private var selectedConversation: Conversation? {
        store.conversations.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            List(store.conversations, selection: $selection) { conversation in
                VStack(alignment: .leading, spacing: 3) {
                    Text(conversation.title)
                        .lineLimit(1)
                    Text(conversation.updatedAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(conversation.id)
            }
            .navigationTitle("History")
        } detail: {
            if let conversation = selectedConversation {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        ForEach(conversation.messages) { message in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(message.role == .user ? "You" : "Screen Sage")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(message.text)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .navigationTitle(conversation.title)
            } else {
                ContentUnavailableView(
                    "Select a Conversation",
                    systemImage: "clock.arrow.circlepath"
                )
            }
        }
        .onAppear {
            selection = selection ?? store.conversations.first?.id
        }
    }
}
