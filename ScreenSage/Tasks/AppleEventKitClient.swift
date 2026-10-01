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

    init(id: String, title: String, color: SourceColor) {
        self.id = id
        self.title = title
        self.color = color
    }

    init(_ calendar: EKCalendar) {
        id = calendar.calendarIdentifier
        title = calendar.title
        color = SourceColor(calendar.color)
    }
}

struct AppleReminderItem: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var dueDate: Date?
    var hasTime: Bool
    var isCompleted: Bool
    var completedAt: Date?
    var list: AppleSourceCalendar

    init(
        id: String,
        title: String,
        dueDate: Date? = nil,
        hasTime: Bool = false,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        list: AppleSourceCalendar
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.list = list
    }

    init(_ reminder: EKReminder) {
        let components = reminder.dueDateComponents
        id = reminder.calendarItemIdentifier
        title = reminder.title ?? ""
        dueDate = components.flatMap { ($0.calendar ?? .current).date(from: $0) }
        hasTime = components?.hour != nil
        isCompleted = reminder.isCompleted
        completedAt = reminder.completionDate
        list = AppleSourceCalendar(reminder.calendar)
    }
}

struct AppleEventItem: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var start: Date
    var end: Date
    var isAllDay: Bool
    var calendar: AppleSourceCalendar

    init(id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, calendar: AppleSourceCalendar) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendar = calendar
    }

    init(_ event: EKEvent) {
        // Occurrences of a recurring event share an identifier, so the start date keeps them distinct.
        id = "\(event.calendarItemIdentifier)@\(event.startDate.timeIntervalSinceReferenceDate)"
        title = event.title ?? ""
        start = event.startDate
        end = event.endDate
        isAllDay = event.isAllDay
        calendar = AppleSourceCalendar(event.calendar)
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

    func addReminder(title: String, dueDate: Date?, notes: String, listID: String) throws {
        guard let list = store.calendar(withIdentifier: listID) ?? store.defaultCalendarForNewReminders() else {
            throw Self.error("No Reminders list is available.")
        }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = list
        reminder.title = title
        reminder.notes = notes.isEmpty ? nil : notes
        if let dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
        }
        try store.save(reminder, commit: true)
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
