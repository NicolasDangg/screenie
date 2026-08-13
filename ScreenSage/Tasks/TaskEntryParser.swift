import Foundation

struct TaskEntryParser {
    private static let dueExpression = try! NSRegularExpression(
        pattern: #"\s+(?:due(?:\s+on)?|by)\s+(.+?)\s*$"#,
        options: [.caseInsensitive]
    )

    static func parse(
        _ entry: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> ScreenieTask {
        let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TaskEntryParserError.emptyTitle }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = dueExpression.firstMatch(in: trimmed, range: range),
              let valueRange = Range(match.range(at: 1), in: trimmed),
              let fullRange = Range(match.range, in: trimmed) else {
            return ScreenieTask(title: trimmed)
        }

        let title = trimmed[..<fullRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let dueText = String(trimmed[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw TaskEntryParserError.emptyTitle }
        guard let dueDate = parseDate(dueText, now: now, calendar: calendar) else {
            throw TaskEntryParserError.invalidDueDate(dueText)
        }
        return ScreenieTask(title: title, dueDate: dueDate)
    }

    private static func parseDate(_ value: String, now: Date, calendar: Calendar) -> Date? {
        let normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized == "today" { return now }
        if normalized == "tomorrow" { return calendar.date(byAdding: .day, value: 1, to: now) }

        let rawISOParts = normalized.split(separator: "-", omittingEmptySubsequences: false)
        if rawISOParts.count == 3,
           rawISOParts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) {
            let isoParts = rawISOParts.compactMap { Int($0) }
            guard isoParts.count == 3 else { return nil }
            return calendar.date(from: DateComponents(
                year: isoParts[0],
                month: isoParts[1],
                day: isoParts[2],
                hour: calendar.component(.hour, from: now)
            ))
        }

        let wantsNextWeek = normalized.hasPrefix("next ")
        let weekdayText = normalized.replacing(#/^next\s+/#, with: "")
        guard let weekday = weekdayNumber(for: weekdayText) else { return nil }
        var components = DateComponents()
        components.weekday = weekday
        components.hour = calendar.component(.hour, from: now)
        guard var date = calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        ) else { return nil }
        if wantsNextWeek, calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            date = calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        }
        return date
    }

    private static func weekdayNumber(for value: String) -> Int? {
        let aliases = [
            1: ["sun", "sunday"],
            2: ["mon", "monday"],
            3: ["tue", "tues", "tuesday"],
            4: ["wed", "wednesday"],
            5: ["thu", "thur", "thurs", "thursday"],
            6: ["fri", "friday"],
            7: ["sat", "saturday"]
        ]
        return aliases.first(where: { $0.value.contains(value) })?.key
    }
}
