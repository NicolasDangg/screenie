import Foundation

/// Turns a short scheduling phrase such as "Friday at 6", "tomorrow morning", or "Oct 14 5:30pm"
/// into a date, deterministically. The language model only finds the phrase; date math stays here.
enum TaskDateResolver {
    /// Used when a day is given without a time.
    static let defaultHour = 9

    /// Returns `nil` when any part of the phrase isn't understood, so vague text like "eventually" is rejected.
    static func resolve(_ phrase: String, now: Date, calendar: Calendar) -> Date? {
        resolveDetailed(phrase, now: now, calendar: calendar)?.date
    }

    /// Like `resolve`, but also says whether the phrase named a time (rather than just a day).
    static func resolveDetailed(_ phrase: String, now: Date, calendar: Calendar) -> (date: Date, hasTime: Bool)? {
        var text = " " + phrase.lowercased()
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ") + " "
        guard text.contains(where: \.isLetter) || text.contains(where: \.isNumber) else { return nil }

        var day: Date?
        var time: (hour: Int, minute: Int)?
        var periodHour: Int?
        let today = calendar.startOfDay(for: now)

        func consume(_ pattern: String) -> [String]? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else { return nil }
            let groups = (0..<match.numberOfRanges).map { index in
                Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
            }
            text.replaceSubrange(range, with: " ")
            return groups
        }

        if let iso = consume(#" (\d{4})-(\d{1,2})-(\d{1,2}) "#) {
            guard let year = Int(iso[1]), let month = Int(iso[2]), let dayOfMonth = Int(iso[3]),
                  let date = calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth)),
                  calendar.component(.day, from: date) == dayOfMonth else { return nil }
            day = date
        }
        if consume(#" (?:the )?day after (?:tomorrow|tmrw?) "#) != nil {
            day = calendar.date(byAdding: .day, value: 2, to: today)
        }
        if let relative = consume(#" in (\d{1,3}|a|an|one|two|three) (day|days|week|weeks) "#) {
            let words = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3]
            guard let count = Int(relative[1]) ?? words[relative[1]] else { return nil }
            let unit: Calendar.Component = relative[2].hasPrefix("week") ? .weekOfYear : .day
            day = calendar.date(byAdding: unit, value: count, to: today)
        }
        if consume(#" next week "#) != nil {
            let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
            day = calendar.date(byAdding: .weekOfYear, value: 1, to: thisWeek)
        }
        if let weekday = consume(#" (next |this )?(sun|sunday|mon|monday|tue|tues|tuesday|wed|weds|wednesday|thu|thur|thurs|thursday|fri|friday|sat|saturday) "#) {
            guard let number = weekdayNumber(weekday[2]) else { return nil }
            day = nextWeekday(number, after: now, skippingThisWeek: weekday[1].hasPrefix("next"), calendar: calendar)
        }
        if let word = consume(#" (today|tonight|tomorrow|tmrw|tmr) "#) {
            let isTomorrow = ["tomorrow", "tmrw", "tmr"].contains(word[1])
            day = calendar.date(byAdding: .day, value: isTomorrow ? 1 : 0, to: today)
            if word[1] == "tonight" { periodHour = 20 }
        }
        let months = "jan|january|feb|february|mar|march|apr|april|may|jun|june|jul|july|aug|august|sep|sept|september|oct|october|nov|november|dec|december"
        if let monthFirst = consume(#" (\#(months)) (\d{1,2})(?:st|nd|rd|th)?(?: (\d{4}))? "#) {
            day = monthDay(month: monthFirst[1], day: monthFirst[2], year: monthFirst[3], now: now, calendar: calendar)
            guard day != nil else { return nil }
        } else if let dayFirst = consume(#" (\d{1,2})(?:st|nd|rd|th)? (?:of )?(\#(months))(?: (\d{4}))? "#) {
            day = monthDay(month: dayFirst[2], day: dayFirst[1], year: dayFirst[3], now: now, calendar: calendar)
            guard day != nil else { return nil }
        }

        if let clock = consume(#" (?:at |@ ?)?(\d{1,2}):(\d{2}) ?(am|pm)? "#)
            ?? consume(#" (?:at |@ ?)?(\d{1,2})()(?: ?)(am|pm) "#)
            ?? consume(#" (?:at |@ ?)(\d{1,2})()() "#) {
            guard var hour = Int(clock[1]) else { return nil }
            let minute = Int(clock[2]) ?? 0
            switch clock[3] {
            case "am": guard (1...12).contains(hour) else { return nil }; hour %= 12
            case "pm": guard (1...12).contains(hour) else { return nil }; hour = hour % 12 + 12
            default:
                // "at 6" almost always means the evening; 8–11 reads as morning.
                if (1...7).contains(hour) { hour += 12 }
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            time = (hour, minute)
        }
        if let period = consume(#" (?:in the |this )?(noon|midday|midnight|morning|afternoon|evening|night) "#) {
            periodHour = ["noon": 12, "midday": 12, "midnight": 0, "morning": 9, "afternoon": 15, "evening": 18, "night": 20][period[1]]
        }

        // Anything left must be a connector word; otherwise the phrase wasn't understood.
        let leftovers = text.split(separator: " ").filter {
            !["due", "on", "by", "at", "for", "the", "before", "this", "until", "til", "till"].contains($0)
        }
        guard leftovers.isEmpty else { return nil }
        guard day != nil || time != nil || periodHour != nil else { return nil }

        let hour = time?.hour ?? periodHour ?? defaultHour
        let minute = time?.minute ?? 0
        guard var resolved = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day ?? today) else {
            return nil
        }
        // A bare time that has already passed today means tomorrow.
        if day == nil, resolved <= now {
            resolved = calendar.date(byAdding: .day, value: 1, to: resolved) ?? resolved
        }
        return (resolved, time != nil || periodHour != nil)
    }

    /// Finds a scheduling phrase at the start or end of `entry` and returns the rest as the title.
    static func split(_ entry: String, now: Date, calendar: Calendar) -> (title: String, dueDate: Date?) {
        split(entry) { resolve($0, now: now, calendar: calendar) }
    }

    /// The event version of `split`: finds a phrase such as "tomorrow 12-1" at either end of `entry`.
    static func splitEvent(_ entry: String, now: Date, calendar: Calendar) -> (title: String, timing: EventTiming?) {
        split(entry) { resolveEvent($0, now: now, calendar: calendar) }
    }

    private static func split<Value>(_ entry: String, resolve: (String) -> Value?) -> (String, Value?) {
        let words = entry.split(whereSeparator: \.isWhitespace).map(String.init)
        guard words.count > 1 else { return (entry, nil) }
        for count in stride(from: min(8, words.count - 1), through: 1, by: -1) {
            if let value = resolve(words.suffix(count).joined(separator: " ")) {
                return (trimConnectors(words.dropLast(count)), value)
            }
            if let value = resolve(words.prefix(count).joined(separator: " ")) {
                return (trimConnectors(words.dropFirst(count)), value)
            }
        }
        return (entry, nil)
    }

    static func trimConnectors<S: Collection>(_ words: S) -> String where S.Element == String {
        var words = Array(words)
        let connectors: Set<String> = ["due", "on", "by", "at", "for", "before", "this", "until", "-", "–"]
        while let last = words.last, connectors.contains(last.lowercased()) { words.removeLast() }
        while let first = words.first, connectors.contains(first.lowercased()) { words.removeFirst() }
        return words.joined(separator: " ")
    }

    private static func weekdayNumber(_ name: String) -> Int? {
        let prefixes = ["sun": 1, "mon": 2, "tue": 3, "wed": 4, "thu": 5, "fri": 6, "sat": 7]
        return prefixes.first { name.hasPrefix($0.key) }?.value
    }

    private static func nextWeekday(_ weekday: Int, after now: Date, skippingThisWeek: Bool, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        guard var date = calendar.nextDate(
            after: today,
            matching: DateComponents(weekday: weekday),
            matchingPolicy: .nextTime
        ) else { return nil }
        if skippingThisWeek, calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            date = calendar.date(byAdding: .weekOfYear, value: 1, to: date) ?? date
        }
        return date
    }

    private static func monthDay(month: String, day: String, year: String, now: Date, calendar: Calendar) -> Date? {
        let names = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        guard let monthIndex = names.firstIndex(where: { month.hasPrefix($0) }),
              let dayOfMonth = Int(day) else { return nil }
        let today = calendar.startOfDay(for: now)
        var components = DateComponents(month: monthIndex + 1, day: dayOfMonth)
        components.year = Int(year) ?? calendar.component(.year, from: now)
        guard var date = calendar.date(from: components),
              calendar.component(.day, from: date) == dayOfMonth else { return nil }
        // "Jan 5" written in December means next year.
        if year.isEmpty, date < today {
            date = calendar.date(byAdding: .year, value: 1, to: date) ?? date
        }
        return date
    }
}
