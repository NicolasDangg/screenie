import Foundation

struct EventTiming: Equatable, Sendable {
    let start: Date
    let end: Date
    let isAllDay: Bool
}

/// A calendar event read from a natural-language entry, ready to save with EventKit.
struct ParsedEvent: Equatable, Sendable {
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let notes: String

    init(title: String, timing: EventTiming, notes: String = "") {
        self.title = title
        start = timing.start
        end = timing.end
        isAllDay = timing.isAllDay
        self.notes = notes
    }
}

extension TaskDateResolver {
    /// Used when an event names a start time but no end or duration.
    static let defaultEventDuration: TimeInterval = 60 * 60

    /// Reads an event phrase such as "tomorrow 12-1", "Friday from 3 to 4:30pm", "9:30 for 15 min",
    /// or "Oct 14" (all-day). Start-time rules match `resolve`.
    static func resolveEvent(_ phrase: String, now: Date, calendar: Calendar) -> EventTiming? {
        var text = " " + phrase.lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: "")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ") + " "

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

        var duration: TimeInterval?
        if let match = consume(#" for (\d{1,3}|an|a|one|two|three|half an) ?(hours?|hrs?|h|minutes?|mins?|m) "#) {
            let words: [String: Double] = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "half an": 0.5]
            guard let amount = Double(match[1]) ?? words[match[1]] else { return nil }
            duration = match[2].hasPrefix("h") ? amount * 3600 : amount * 60
        }

        var endClock: (hour: Int, minute: Int)?
        let clock = #"(\d{1,2})(?::(\d{2}))? ?(am|pm)?"#
        if let range = consume(#" (?:from |at )?\#(clock) ?(?:-|to|until|till) ?\#(clock) "#) {
            guard var startHour = Int(range[1]), var endHour = Int(range[4]) else { return nil }
            let startMinute = Int(range[2]) ?? 0
            let endMinute = Int(range[5]) ?? 0
            var startMeridiem = range[3]
            let endMeridiem = range[6]
            // "12-1pm" and "3-4pm" borrow the end's am/pm, unless that would start after it ends ("11-1pm").
            if startMeridiem.isEmpty, !endMeridiem.isEmpty {
                startMeridiem = endMeridiem
                if let start = to24Hour(startHour, startMeridiem), let end = to24Hour(endHour, endMeridiem), start > end {
                    startMeridiem = endMeridiem == "pm" ? "am" : "pm"
                }
            }
            guard let start24 = to24Hour(startHour, startMeridiem),
                  let end24 = to24Hour(endHour, endMeridiem.isEmpty ? startMeridiem : endMeridiem) else { return nil }
            startHour = start24
            endHour = end24
            // Without any am/pm, "12-1" means midday and an end before the start rolls into the afternoon.
            if endMeridiem.isEmpty, endHour < startHour, endHour + 12 > startHour {
                endHour += 12
            }
            guard (0...59).contains(startMinute), (0...59).contains(endMinute) else { return nil }
            // Hand the start back with an explicit am/pm so `resolveDetailed` doesn't re-guess it.
            let hour12 = startHour % 12 == 0 ? 12 : startHour % 12
            text.append(" at \(hour12):\(String(format: "%02d", startMinute)) \(startHour < 12 ? "am" : "pm") ")
            endClock = (endHour, endMinute)
        }

        guard let start = resolveDetailed(text, now: now, calendar: calendar) else { return nil }

        if !start.hasTime, duration == nil, endClock == nil {
            let day = calendar.startOfDay(for: start.date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            return EventTiming(start: day, end: next, isAllDay: true)
        }

        var end: Date
        if let endClock {
            guard let sameDay = calendar.date(
                bySettingHour: endClock.hour,
                minute: endClock.minute,
                second: 0,
                of: start.date
            ) else { return nil }
            end = sameDay
            if end <= start.date { end = calendar.date(byAdding: .day, value: 1, to: end) ?? end }
        } else {
            end = start.date.addingTimeInterval(duration ?? defaultEventDuration)
        }
        return EventTiming(start: start.date, end: end, isAllDay: false)
    }

    /// Converts a 12-hour clock to 24-hour. With no am/pm, small hours read as afternoon ("3-4" → 15:00).
    private static func to24Hour(_ hour: Int, _ meridiem: String) -> Int? {
        switch meridiem {
        case "am":
            guard (1...12).contains(hour) else { return nil }
            return hour % 12
        case "pm":
            guard (1...12).contains(hour) else { return nil }
            return hour % 12 + 12
        default:
            guard (0...23).contains(hour) else { return nil }
            return (1...7).contains(hour) ? hour + 12 : hour
        }
    }
}
