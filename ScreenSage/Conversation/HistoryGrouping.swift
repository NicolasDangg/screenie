import Foundation

struct HistorySection: Identifiable, Equatable {
    let title: String
    let conversations: [Conversation]

    var id: String { title }
}

/// Sidebar grouping, search, and labels for the History window.
enum HistoryGrouping {
    /// Today, Yesterday, Previous 7 Days, then one section per month, newest first.
    static func sections(for conversations: [Conversation], now: Date, calendar: Calendar) -> [HistorySection] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        var order: [String] = []
        var groups: [String: [Conversation]] = [:]

        for conversation in conversations.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            let date = conversation.updatedAt
            let title = if date >= today {
                "Today"
            } else if date >= yesterday {
                "Yesterday"
            } else if date >= weekAgo {
                "Previous 7 Days"
            } else {
                date.formatted(.dateTime.month(.wide).year())
            }
            if groups[title] == nil { order.append(title) }
            groups[title, default: []].append(conversation)
        }
        return order.map { HistorySection(title: $0, conversations: groups[$0] ?? []) }
    }

    static func matches(_ conversation: Conversation, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return conversation.title.localizedCaseInsensitiveContains(query)
            || conversation.messages.contains { $0.text.localizedCaseInsensitiveContains(query) }
    }

    /// The first line of the first answer, with Markdown punctuation removed.
    static func preview(of conversation: Conversation) -> String {
        let answer = conversation.messages.first { $0.role == .assistant }?.text
            ?? conversation.messages.first?.text
            ?? ""
        let line = answer
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty && !$0.hasPrefix("```") } ?? ""
        return line
            .replacingOccurrences(of: #"[#*_`>\[\]]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// A time for today and yesterday, a weekday within the last week, otherwise a short date.
    static func timeLabel(for date: Date, now: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        if date >= yesterday {
            return date.formatted(date: .omitted, time: .shortened)
        } else if date >= weekAgo {
            return date.formatted(.dateTime.weekday(.abbreviated))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
