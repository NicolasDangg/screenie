import Foundation
import FoundationModels

@Generable
private struct GeneratedTaskEntry {
    @Guide(description: "A concise task title with scheduling words removed")
    let title: String

    @Guide(description: "The due date and time as ISO 8601 with a numeric UTC offset, or nil when no schedule is stated")
    let dueDateISO8601: String?

    @Guide(description: "Only extra details explicitly stated by the user, or an empty string")
    let notes: String
}

struct FoundationModelTaskParser {
    static func parse(
        _ entry: String,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) async throws -> ScreenieTask {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        guard SystemLanguageModel.default.availability == .available else {
            return try TaskEntryParser.parse(entry, now: now, calendar: calendar)
        }

        do {
            let formatter = ISO8601DateFormatter()
            formatter.timeZone = timeZone
            let session = LanguageModelSession(instructions: """
                Extract one task from the user's text.
                Current local date and time: \(formatter.string(from: now))
                Time zone: \(timeZone.identifier)
                Resolve relative dates and times against that context.
                When a date is given without a time, use 09:00 local time.
                Do not invent notes or a due date.
                """)
            let generated = try await session.respond(
                to: entry,
                generating: GeneratedTaskEntry.self
            ).content
            return reconcileDueDate(
                in: try makeTask(
                    title: generated.title,
                    dueDateISO8601: generated.dueDateISO8601,
                    notes: generated.notes,
                    createdAt: now
                ),
                entry: entry,
                now: now,
                calendar: calendar
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            return try TaskEntryParser.parse(entry, now: now, calendar: calendar)
        }
    }

    static func makeTask(
        title: String,
        dueDateISO8601: String?,
        notes: String,
        createdAt: Date = .now
    ) throws -> ScreenieTask {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw TaskEntryParserError.emptyTitle }

        let dueText = dueDateISO8601?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dueDate: Date?
        if let dueText, !dueText.isEmpty {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            guard let parsedDate = ISO8601DateFormatter().date(from: dueText)
                    ?? formatter.date(from: dueText) else {
                throw TaskEntryParserError.invalidDueDate(dueText)
            }
            dueDate = parsedDate
        } else {
            dueDate = nil
        }

        return ScreenieTask(
            title: title,
            dueDate: dueDate,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt
        )
    }

    static func reconcileDueDate(
        in task: ScreenieTask,
        entry: String,
        now: Date,
        calendar: Calendar
    ) -> ScreenieTask {
        var corrected = task
        let words = entry.split(whereSeparator: \Character.isWhitespace)
        let anchor = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now

        for count in [2, 1] where words.count >= count {
            let suffix = words.suffix(count).joined(separator: " ")
            if let dueDate = try? TaskEntryParser.parse(
                "Task due \(suffix)",
                now: anchor,
                calendar: calendar
            ).dueDate {
                corrected.dueDate = dueDate
                break
            }
        }
        return corrected
    }
}
