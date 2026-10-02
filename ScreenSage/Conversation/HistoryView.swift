import AppKit
import SwiftUI

struct HistoryView: View {
    @Bindable var store: ChatHistoryStore
    let continueConversation: (Conversation) -> Void
    @State private var selection: Conversation.ID?
    @State private var searchText = ""

    private var filtered: [Conversation] {
        store.conversations.filter { HistoryGrouping.matches($0, query: searchText) }
    }

    private var selectedConversation: Conversation? {
        store.conversations.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(HistoryGrouping.sections(for: filtered, now: .now, calendar: .autoupdatingCurrent)) { section in
                    Section(section.title) {
                        ForEach(section.conversations) { conversation in
                            HistoryRow(conversation: conversation)
                                .tag(conversation.id)
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search")
            .overlay {
                if filtered.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "No Conversations",
                            systemImage: "bubble.left.and.text.bubble.right",
                            description: Text("Press ⌥Space to ask about your screen.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 380)
        } detail: {
            if let conversation = selectedConversation {
                HistoryConversationView(conversation: conversation, continueConversation: continueConversation)
            } else {
                ContentUnavailableView("Select a Conversation", systemImage: "clock.arrow.circlepath")
            }
        }
        .onAppear {
            selection = selection ?? store.conversations.first?.id
        }
    }
}

private struct HistoryRow: View {
    let conversation: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(conversation.title)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(HistoryGrouping.timeLabel(for: conversation.updatedAt, now: .now, calendar: .autoupdatingCurrent))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(HistoryGrouping.preview(of: conversation))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

private struct HistoryConversationView: View {
    let conversation: Conversation
    let continueConversation: (Conversation) -> Void
    @State private var didCopy = false

    private var subtitle: String {
        let when = conversation.updatedAt.formatted(.relative(presentation: .named, unitsStyle: .wide))
        let count = conversation.messages.count
        return "\(when.prefix(1).uppercased() + when.dropFirst()) · \(count) \(count == 1 ? "message" : "messages")"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(conversation.messages) { message in
                    if message.role == .assistant {
                        AssistantResponseText(text: message.text)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        userMessage(message.text)
                    }
                }
                Text("Screenshots and OCR text aren’t saved — only the conversation.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(conversation.title)
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem {
                Button(didCopy ? "Copied" : "Copy Conversation", systemImage: didCopy ? "checkmark" : "doc.on.doc", action: copy)
                    .help("Copy conversation")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Continue in Overlay", systemImage: "arrow.up.forward.app") {
                    continueConversation(conversation)
                }
                .help("Continue this conversation in the overlay")
            }
        }
    }

    private func userMessage(_ text: String) -> some View {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return Text((try? AttributedString(markdown: text, options: options)) ?? AttributedString(text))
            .textSelection(.enabled)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                .primary.opacity(0.08),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 14,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 14
                )
            )
            .padding(.leading, 80)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func copy() {
        let text = conversation.messages
            .map { "\($0.role == .user ? "You" : "screenie"): \($0.text)" }
            .joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            didCopy = false
        }
    }
}
