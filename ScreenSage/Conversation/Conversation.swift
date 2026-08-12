import Foundation

struct Conversation: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    static func cleanedTitle(_ generated: String, fallbackPrompt: String) -> String {
        let cleaned = generated
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”"))
            .split(separator: "\n", maxSplits: 1)
            .first
            .map(String.init) ?? ""
        if !cleaned.isEmpty { return cleaned }
        let fallback = fallbackPrompt.split(whereSeparator: \Character.isWhitespace).prefix(6).joined(separator: " ")
        return fallback.isEmpty ? "New Chat" : fallback
    }
}
