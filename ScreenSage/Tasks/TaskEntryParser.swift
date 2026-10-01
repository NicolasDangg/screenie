import Foundation

/// The rule-based parser, used when Apple Intelligence is unavailable or fails.
struct TaskEntryParser {
    private static let dueExpression = try! NSRegularExpression(
        pattern: #"\s+due(?:\s+on)?\s+(.+?)\s*$"#,
        options: [.caseInsensitive]
    )

    static func parse(
        _ entry: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> ScreenieTask {
        let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TaskEntryParserError.emptyTitle }

        // An explicit "due …" must be understood; guessing a date here would be worse than asking again.
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if let match = dueExpression.firstMatch(in: trimmed, range: range),
           let valueRange = Range(match.range(at: 1), in: trimmed),
           let fullRange = Range(match.range, in: trimmed) {
            let title = trimmed[..<fullRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let dueText = String(trimmed[valueRange])
            guard !title.isEmpty else { throw TaskEntryParserError.emptyTitle }
            guard let dueDate = TaskDateResolver.resolve(dueText, now: now, calendar: calendar) else {
                throw TaskEntryParserError.invalidDueDate(dueText)
            }
            return ScreenieTask(title: title, dueDate: dueDate, createdAt: now)
        }

        let split = TaskDateResolver.split(trimmed, now: now, calendar: calendar)
        guard !split.title.isEmpty else { throw TaskEntryParserError.emptyTitle }
        return ScreenieTask(title: split.title, dueDate: split.dueDate, createdAt: now)
    }
}
