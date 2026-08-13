import Foundation

struct TaskSchedule: Codable, Equatable, Sendable {
    let summary: String
    let suggestions: [TaskScheduleSuggestion]

    static func decodeOpenRouterResponse(_ data: Data) throws -> TaskSchedule {
        guard let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = response["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw TaskScheduleError.invalidResponse
        }
        return try decodeContent(contentData)
    }

    static func decodeContent(_ data: Data) throws -> TaskSchedule {
        try validateKeys(in: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let schedule = try decoder.decode(TaskSchedule.self, from: data)
        guard !schedule.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TaskScheduleError.invalidResponse
        }
        guard schedule.suggestions.allSatisfy({ suggestion in
            !suggestion.taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !suggestion.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && suggestion.end > suggestion.start
        }) else {
            throw TaskScheduleError.invalidSuggestion
        }
        return schedule
    }

    private static func validateKeys(in data: Data) throws {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["summary", "suggestions"],
              let suggestions = object["suggestions"] as? [[String: Any]],
              suggestions.allSatisfy({ Set($0.keys) == ["taskTitle", "start", "end", "note"] }) else {
            throw TaskScheduleError.invalidResponse
        }
    }
}
