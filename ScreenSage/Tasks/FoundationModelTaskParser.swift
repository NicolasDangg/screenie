import Foundation
import FoundationModels

@Generable
private struct GeneratedTaskEntry {
    @Guide(description: "The task itself in the user's words, without any date or time words")
    let title: String

    @Guide(description: "The exact words from the user's text that say when it happens or is due, copied verbatim, such as \"Friday at 6\", \"tomorrow 12-1\", or \"tomorrow morning\". Empty when no date or time is stated.")
    let schedulePhrase: String

    @Guide(description: "Extra details copied from the user's text that are neither the task nor its timing, or an empty string")
    let notes: String
}

/// Parses a task or event on-device. The model only splits the entry into title, scheduling phrase, and notes;
/// `TaskDateResolver` turns the phrase into a date, because small models are unreliable at date math.
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
            let generated = try await generate(entry)
            return try makeTask(
                entry: entry,
                title: generated.title,
                schedulePhrase: generated.schedulePhrase,
                notes: generated.notes,
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

    /// Parses a calendar event. Falls back to the rule-based reader when the model is unavailable or fails.
    static func parseEvent(
        _ entry: String,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) async throws -> ParsedEvent {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        if SystemLanguageModel.default.availability == .available {
            do {
                let generated = try await generate(entry)
                return try makeEvent(
                    entry: entry,
                    title: generated.title,
                    schedulePhrase: generated.schedulePhrase,
                    notes: generated.notes,
                    now: now,
                    calendar: calendar
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
            }
        }
        return try makeEvent(entry: entry, title: "", schedulePhrase: "", notes: "", now: now, calendar: calendar)
    }

    private static func generate(_ entry: String) async throws -> GeneratedTaskEntry {
        let session = LanguageModelSession(instructions: """
            Split the user's text into one task or event.
            Copy words from the text exactly; do not rephrase, translate, or add anything.
            Put only the words that say when it happens or is due in schedulePhrase.
            Leave notes empty unless the text has details beyond the item and its timing.
            """)
        return try await session.respond(
            to: entry,
            generating: GeneratedTaskEntry.self,
            options: GenerationOptions(sampling: .greedy)
        ).content
    }

    /// Validates model output against the entry, like `makeTask`, but needs a time range rather than a due date.
    static func makeEvent(
        entry: String,
        title: String,
        schedulePhrase: String,
        notes: String,
        now: Date,
        calendar: Calendar
    ) throws -> ParsedEvent {
        let entry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty else { throw TaskEntryParserError.emptyTitle }
        let phrase = schedulePhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = TaskDateResolver.splitEvent(entry, now: now, calendar: calendar)

        var timing: EventTiming?
        var cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phrase.isEmpty, entry.range(of: phrase, options: .caseInsensitive) != nil {
            timing = TaskDateResolver.resolveEvent(phrase, now: now, calendar: calendar)
            if let range = cleanedTitle.range(of: phrase, options: .caseInsensitive) {
                cleanedTitle.removeSubrange(range)
            }
        }
        if timing == nil {
            timing = fallback.timing
            cleanedTitle = fallback.title
        }
        guard let timing else { throw TaskEntryParserError.missingEventTime }

        cleanedTitle = TaskDateResolver.trimConnectors(
            cleanedTitle.split(whereSeparator: \.isWhitespace).map(String.init)
        )
        if cleanedTitle.isEmpty { cleanedTitle = fallback.title }
        guard !cleanedTitle.isEmpty else { throw TaskEntryParserError.emptyTitle }

        return ParsedEvent(title: cleanedTitle, timing: timing, notes: checkedNotes(notes, entry: entry, title: cleanedTitle, phrase: phrase))
    }

    private static func checkedNotes(_ notes: String, entry: String, title: String, phrase: String) -> String {
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entry.range(of: notes, options: .caseInsensitive) != nil,
              notes.caseInsensitiveCompare(title) != .orderedSame,
              notes.caseInsensitiveCompare(phrase) != .orderedSame else { return "" }
        return notes
    }

    /// Validates model output against the original entry so nothing invented reaches the task.
    static func makeTask(
        entry: String,
        title: String,
        schedulePhrase: String,
        notes: String,
        now: Date,
        calendar: Calendar
    ) throws -> ScreenieTask {
        let entry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        let phrase = schedulePhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = try TaskEntryParser.parse(entry, now: now, calendar: calendar)

        // Trust the phrase only if it really appears in the entry and resolves to a date.
        var dueDate: Date?
        var cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phrase.isEmpty, entry.range(of: phrase, options: .caseInsensitive) != nil {
            dueDate = TaskDateResolver.resolve(phrase, now: now, calendar: calendar)
            if let range = cleanedTitle.range(of: phrase, options: .caseInsensitive) {
                cleanedTitle.removeSubrange(range)
            }
        }
        if dueDate == nil, let fallbackDate = fallback.dueDate {
            // The model missed or invented the timing, so its title likely still holds the date words.
            dueDate = fallbackDate
            cleanedTitle = fallback.title
        }

        cleanedTitle = TaskDateResolver.trimConnectors(
            cleanedTitle.split(whereSeparator: \.isWhitespace).map(String.init)
        )
        if cleanedTitle.isEmpty { cleanedTitle = fallback.title }
        guard !cleanedTitle.isEmpty else { throw TaskEntryParserError.emptyTitle }

        return ScreenieTask(
            title: cleanedTitle,
            dueDate: dueDate,
            notes: checkedNotes(notes, entry: entry, title: cleanedTitle, phrase: phrase),
            createdAt: now
        )
    }
}
