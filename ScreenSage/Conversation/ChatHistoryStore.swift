import Foundation
import Observation

@MainActor
@Observable
final class ChatHistoryStore {
    private(set) var conversations: [Conversation] = []
    private(set) var lastError = ""
    private let fileURL: URL

    init(fileURL: URL = ChatHistoryStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    func upsert(_ conversation: Conversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
        conversations.sort { $0.updatedAt > $1.updatedAt }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            conversations = try JSONDecoder().decode([Conversation].self, from: Data(contentsOf: fileURL))
            conversations.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            lastError = "Could not load history: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(conversations).write(to: fileURL, options: .atomic)
            lastError = ""
        } catch {
            lastError = "Could not save history: \(error.localizedDescription)"
        }
    }

    private static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appending(path: "ScreenSage/history.json")
    }
}
