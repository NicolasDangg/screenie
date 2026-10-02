import AppKit
import EventKit
import Foundation

struct SourceColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(_ color: NSColor?) {
        let rgb = color?.usingColorSpace(.sRGB)
        red = rgb.map { Double($0.redComponent) } ?? 0.55
        green = rgb.map { Double($0.greenComponent) } ?? 0.57
        blue = rgb.map { Double($0.blueComponent) } ?? 0.61
    }
}

/// A Reminders list or Calendar calendar, reduced to the fields the task views need.
struct AppleSourceCalendar: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let color: SourceColor
    /// False for subscribed and read-only calendars, which can't take new events.
    var allowsModifications = true

    init(id: String, title: String, color: SourceColor, allowsModifications: Bool = true) {
        self.id = id
        self.title = title
        self.color = color
        self.allowsModifications = allowsModifications
    }

    init(_ calendar: EKCalendar) {
        id = calendar.calendarIdentifier
        title = calendar.title
        color = SourceColor(calendar.color)
        allowsModifications = calendar.allowsContentModifications
    }
}

struct AppleReminderItem: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var notes: String
    var dueDate: Date?
    var hasTime: Bool
    var isCompleted: Bool
    var completedAt: Date?
    var list: AppleSourceCalendar
    /// Opens this reminder in the Reminders app.
    var appURL: URL?

    init(
        id: String,
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        hasTime: Bool = false,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        list: AppleSourceCalendar,
        appURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.list = list
        self.appURL = appURL
    }

    init(_ reminder: EKReminder) {
        let components = reminder.dueDateComponents
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? ""
        notes = reminder.notes ?? ""
        dueDate = components.flatMap { ($0.calendar ?? .current).date(from: $0) }
        hasTime = components?.hour != nil
        isCompleted = reminder.isCompleted
        completedAt = reminder.completionDate
        list = AppleSourceCalendar(reminder.calendar)
        appURL = Self.appURL(calendarItemID: reminder.calendarItemIdentifier)
    }

    /// The Reminders app's own deep link; there is no public API for showing a reminder.
    static func appURL(calendarItemID: String) -> URL? {
        URL(string: "x-apple-reminderkit://REMCDReminder/\(calendarItemID)")
    }
}

struct AppleEventItem: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendar: AppleSourceCalendar
    /// Opens this event (or occurrence) in the Calendar app.
    var appURL: URL?

    init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        calendar: AppleSourceCalendar,
        appURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendar = calendar
        self.appURL = appURL
    }

    init(_ event: EKEvent) {
        // Occurrences of a recurring event share an identifier, so the start date keeps them distinct.
        id = "\(event.calendarItemIdentifier)@\(event.startDate.timeIntervalSinceReferenceDate)"
        title = event.title ?? ""
        start = event.startDate
        end = event.endDate
        isAllDay = event.isAllDay
        calendar = AppleSourceCalendar(event.calendar)
        appURL = Self.appURL(
            calendarItemID: event.calendarItemIdentifier,
            occurrenceStart: event.hasRecurrenceRules ? event.startDate : nil,
            isAllDay: event.isAllDay
        )
    }

    /// Calendar's own deep link. Recurring events need the occurrence start, written in UTC for timed
    /// events and as local wall-clock time for all-day ones; both use a literal trailing `Z`.
    static func appURL(
        calendarItemID: String,
        occurrenceStart: Date?,
        isAllDay: Bool,
        timeZone: TimeZone = .current
    ) -> URL? {
        var path = ""
        if let occurrenceStart {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = isAllDay ? timeZone : TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            path = "/\(formatter.string(from: occurrenceStart))"
        }
        return URL(string: "ical://ekevent\(path)/\(calendarItemID)?method=show&options=more")
    }
}

enum AppleSourceAccess: Equatable, Sendable {
    case notDetermined
    case granted
    case denied

    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .fullAccess: self = .granted
        case .notDetermined: self = .notDetermined
        default: self = .denied
        }
    }

    static func current(for entity: EKEntityType) -> AppleSourceAccess {
        AppleSourceAccess(EKEventStore.authorizationStatus(for: entity))
    }
}

/// Reads and writes Apple Reminders and Calendar. Results are returned as value types and never persisted.
actor AppleEventKitClient {
    private let store = EKEventStore()

    func requestAccess(to entity: EKEntityType) async throws -> Bool {
        entity == .reminder
            ? try await store.requestFullAccessToReminders()
            : try await store.requestFullAccessToEvents()
    }

    func calendars(for entity: EKEntityType) -> [AppleSourceCalendar] {
        store.calendars(for: entity)
            .map(AppleSourceCalendar.init)
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    func events(in interval: DateInterval, calendarIDs: Set<String>) -> [AppleEventItem] {
        let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: calendars)
        return store.events(matching: predicate)
            .filter { !TaskAgenda.isManagedByScreenie(notes: $0.notes) }
            .map(AppleEventItem.init)
    }

    func reminders(listIDs: Set<String>, now: Date, calendar: Calendar) async -> [AppleReminderItem] {
        let lists = store.calendars(for: .reminder).filter { listIDs.contains($0.calendarIdentifier) }
        guard !lists.isEmpty else { return [] }
        let startOfToday = calendar.startOfDay(for: now)
        let incomplete = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: lists
        )
        let completedToday = store.predicateForCompletedReminders(
            withCompletionDateStarting: startOfToday,
            ending: now.addingTimeInterval(60),
            calendars: lists
        )
        return await fetchReminders(matching: incomplete) + fetchReminders(matching: completedToday)
    }

    func setReminder(_ id: String, completed: Bool) throws {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw Self.error("That reminder no longer exists.")
        }
        reminder.isCompleted = completed
        try store.save(reminder, commit: true)
    }

    /// Saves to exactly `listID`; never falls back to another list, so nothing lands somewhere unexpected.
    func addReminder(title: String, dueDate: Date?, notes: String, listID: String) throws -> URL? {
        guard let list = store.calendar(withIdentifier: listID), list.allowedEntityTypes.contains(.reminder) else {
            throw Self.error("That Reminders list is no longer available.")
        }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        reminder.title = title
        reminder.notes = notes.isEmpty ? nil : notes
        reminder.dueDateComponents = Self.dueDateComponents(dueDate, hasTime: true)
        try store.save(reminder, commit: true)
        return AppleReminderItem.appURL(calendarItemID: reminder.calendarItemIdentifier)
    }

    func updateReminder(_ id: String, title: String, notes: String, dueDate: Date?, hasTime: Bool) throws {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw Self.error("That reminder no longer exists.")
        }
        let components = Self.dueDateComponents(dueDate, hasTime: hasTime)
        if components != reminder.dueDateComponents {
            // Reminders' time-based alert sits at the old due time; move it with the date instead of leaving it behind.
            let timedAlarms = reminder.alarms?.filter { $0.absoluteDate != nil } ?? []
            timedAlarms.forEach(reminder.removeAlarm)
            if !timedAlarms.isEmpty, hasTime, let dueDate {
                reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            }
            reminder.dueDateComponents = components
        }
        reminder.title = title
        reminder.notes = notes.isEmpty ? nil : notes
        try store.save(reminder, commit: true)
    }

    nonisolated static func dueDateComponents(_ date: Date?, hasTime: Bool) -> DateComponents? {
        guard let date else { return nil }
        let units: Set<Calendar.Component> = hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        return Calendar.current.dateComponents(units, from: date)
    }

    func addEvent(_ event: ParsedEvent, calendarID: String) throws -> URL? {
        guard let calendar = store.calendar(withIdentifier: calendarID), calendar.allowsContentModifications else {
            throw Self.error("That calendar can't take new events.")
        }
        let newEvent = EKEvent(eventStore: store)
        newEvent.calendar = calendar
        newEvent.title = event.title
        newEvent.startDate = event.start
        newEvent.endDate = event.end
        newEvent.isAllDay = event.isAllDay
        newEvent.notes = event.notes.isEmpty ? nil : event.notes
        try store.save(newEvent, span: .thisEvent, commit: true)
        return AppleEventItem.appURL(
            calendarItemID: newEvent.calendarItemIdentifier,
            occurrenceStart: nil,
            isAllDay: newEvent.isAllDay
        )
    }

    private func fetchReminders(matching predicate: NSPredicate) async -> [AppleReminderItem] {
        await withCheckedContinuation { continuation in
            // EventKit calls back on its own queue, so the handler must not inherit actor isolation.
            store.fetchReminders(matching: predicate) { @Sendable reminders in
                continuation.resume(returning: (reminders ?? []).map(AppleReminderItem.init))
            }
        }
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "screenie.reminders", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
