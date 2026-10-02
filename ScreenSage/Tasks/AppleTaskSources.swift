import EventKit
import Foundation
import Observation

/// Live Reminders and Calendar items shown alongside screenie tasks, plus the preferences that choose them.
@MainActor
@Observable
final class AppleTaskSources {
    enum Keys {
        static let showsReminders = "tasks.showsReminders"
        static let hiddenReminderLists = "tasks.hiddenReminderLists"
        static let showsEvents = "tasks.showsEvents"
        static let hiddenCalendars = "tasks.hiddenCalendars"
        /// Older builds stored only a Reminders list id here; read once to migrate.
        static let legacyNewTaskReminderList = "tasks.newTaskReminderList"
        static let newItemDestination = "tasks.newItemDestination"
        static let syncsTasksToCalendar = "tasks.syncsTasksToCalendar"
    }

    nonisolated static func syncsTasksToCalendar(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: Keys.syncsTasksToCalendar) as? Bool ?? true
    }

    var showsReminders: Bool {
        didSet { defaults.set(showsReminders, forKey: Keys.showsReminders); scheduleRefresh() }
    }
    var showsEvents: Bool {
        didSet { defaults.set(showsEvents, forKey: Keys.showsEvents); scheduleRefresh() }
    }
    private(set) var hiddenReminderListIDs: Set<String> {
        didSet { defaults.set(Array(hiddenReminderListIDs), forKey: Keys.hiddenReminderLists) }
    }
    private(set) var hiddenCalendarIDs: Set<String> {
        didSet { defaults.set(Array(hiddenCalendarIDs), forKey: Keys.hiddenCalendars) }
    }
    /// Where the task panel saves new entries: screenie, a Reminders list, or a calendar as an event.
    var newItemDestination: NewItemDestination {
        didSet { defaults.set(newItemDestination.storageValue, forKey: Keys.newItemDestination) }
    }
    var syncsTasksToCalendar: Bool {
        didSet { defaults.set(syncsTasksToCalendar, forKey: Keys.syncsTasksToCalendar) }
    }

    private(set) var reminderAccess: AppleSourceAccess
    private(set) var eventAccess: AppleSourceAccess
    private(set) var reminderLists: [AppleSourceCalendar] = []
    private(set) var eventCalendars: [AppleSourceCalendar] = []
    private(set) var reminders: [AppleReminderItem] = []
    private(set) var events: [AppleEventItem] = []
    private(set) var lastRefreshed: Date?
    var errorMessage = ""

    private let defaults: UserDefaults
    private let client: AppleEventKitClient?
    private let calendar: Calendar
    private var eventRange: DateInterval
    private var refreshTask: Task<Void, Never>?
    private var pendingCompletions: [String: PendingCompletion] = [:]
    private var changeObserver: NSObjectProtocol?

    init(
        defaults: UserDefaults = .standard,
        client: AppleEventKitClient? = AppleEventKitClient(),
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now
    ) {
        self.defaults = defaults
        self.client = client
        self.calendar = calendar
        showsReminders = defaults.object(forKey: Keys.showsReminders) as? Bool ?? true
        showsEvents = defaults.object(forKey: Keys.showsEvents) as? Bool ?? true
        hiddenReminderListIDs = Set(defaults.stringArray(forKey: Keys.hiddenReminderLists) ?? [])
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Keys.hiddenCalendars) ?? [])
        newItemDestination = defaults.string(forKey: Keys.newItemDestination).flatMap(NewItemDestination.init(storageValue:))
            ?? defaults.string(forKey: Keys.legacyNewTaskReminderList).map(NewItemDestination.reminders)
            ?? .screenie
        syncsTasksToCalendar = Self.syncsTasksToCalendar(in: defaults)
        reminderAccess = client == nil ? .denied : .current(for: .reminder)
        eventAccess = client == nil ? .denied : .current(for: .event)
        let today = calendar.startOfDay(for: now)
        eventRange = DateInterval(
            start: calendar.date(byAdding: .day, value: -7, to: today) ?? today,
            end: calendar.date(byAdding: .day, value: 28, to: today) ?? today
        )
        guard client != nil else { return }
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRefresh() }
        }
    }

    var needsConnection: Bool {
        reminderAccess == .notDetermined || eventAccess == .notDetermined
    }

    var hasConnectedSource: Bool {
        reminderAccess == .granted || eventAccess == .granted
    }

    /// Calendars that can take new events.
    var writableEventCalendars: [AppleSourceCalendar] {
        eventCalendars.filter(\.allowsModifications)
    }

    /// The list or calendar the destination points at, or `nil` when it's screenie or no longer reachable.
    var destinationTarget: AppleSourceCalendar? {
        switch newItemDestination {
        case .screenie:
            nil
        case let .reminders(id):
            reminderAccess == .granted ? reminderLists.first { $0.id == id } : nil
        case let .calendar(id):
            eventAccess == .granted ? writableEventCalendars.first { $0.id == id } : nil
        }
    }

    /// The destination to actually use: falls back to screenie when the chosen list or calendar is gone.
    var effectiveDestination: NewItemDestination {
        destinationTarget == nil ? .screenie : newItemDestination
    }

    func isVisible(_ list: AppleSourceCalendar) -> Bool {
        !hiddenReminderListIDs.contains(list.id) && !hiddenCalendarIDs.contains(list.id)
    }

    func setReminderList(_ list: AppleSourceCalendar, visible: Bool) {
        if visible { hiddenReminderListIDs.remove(list.id) } else { hiddenReminderListIDs.insert(list.id) }
        scheduleRefresh()
    }

    func setCalendar(_ calendar: AppleSourceCalendar, visible: Bool) {
        if visible { hiddenCalendarIDs.remove(calendar.id) } else { hiddenCalendarIDs.insert(calendar.id) }
        scheduleRefresh()
    }

    /// Widens the fetched event window so the week view can page beyond the initial range.
    func showEvents(in interval: DateInterval) {
        guard interval.start < eventRange.start || interval.end > eventRange.end else { return }
        eventRange = DateInterval(
            start: min(interval.start, eventRange.start),
            end: max(interval.end, eventRange.end)
        )
        scheduleRefresh()
    }

    func requestAccess() async {
        if reminderAccess == .notDetermined { await requestAccess(to: .reminder) }
        if eventAccess == .notDetermined { await requestAccess(to: .event) }
    }

    func requestAccess(to entity: EKEntityType) async {
        guard let client else { return }
        do {
            _ = try await client.requestAccess(to: entity)
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
    }

    func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { await refresh() }
    }

    func refresh() async {
        guard let client else { return }
        reminderAccess = .current(for: .reminder)
        eventAccess = .current(for: .event)

        var lists: [AppleSourceCalendar] = []
        var fetchedReminders: [AppleReminderItem] = []
        if reminderAccess == .granted {
            lists = await client.calendars(for: .reminder)
            if showsReminders {
                let ids = Set(lists.map(\.id)).subtracting(hiddenReminderListIDs)
                fetchedReminders = await client.reminders(listIDs: ids, now: .now, calendar: calendar)
            }
        }

        var calendars: [AppleSourceCalendar] = []
        var fetchedEvents: [AppleEventItem] = []
        if eventAccess == .granted {
            calendars = await client.calendars(for: .event)
            if showsEvents {
                let ids = Set(calendars.map(\.id)).subtracting(hiddenCalendarIDs)
                fetchedEvents = await client.events(in: eventRange, calendarIDs: ids)
            }
        }

        guard !Task.isCancelled else { return }
        reminderLists = lists
        reminders = Self.applying(pendingCompletions, to: fetchedReminders)
        eventCalendars = calendars
        events = fetchedEvents
        lastRefreshed = .now
    }

    /// Shows the change immediately and keeps it through any refresh until EventKit has saved it,
    /// so a refresh that lands mid-save can't flip the checkbox back.
    func setReminder(_ reminder: AppleReminderItem, completed: Bool) {
        guard let client else { return }
        let change = PendingCompletion(completed: completed, completedAt: completed ? .now : nil)
        pendingCompletions[reminder.id] = change
        reminders = Self.applying(pendingCompletions, to: reminders)
        Task {
            do {
                try await client.setReminder(reminder.id, completed: completed)
                errorMessage = ""
            } catch {
                errorMessage = "Could not update Reminders: \(error.localizedDescription)"
            }
            if pendingCompletions[reminder.id] == change {
                pendingCompletions[reminder.id] = nil
            }
            await refresh()
        }
    }

    struct PendingCompletion: Equatable {
        let id = UUID()
        let completed: Bool
        let completedAt: Date?
    }

    nonisolated static func applying(
        _ pending: [String: PendingCompletion],
        to reminders: [AppleReminderItem]
    ) -> [AppleReminderItem] {
        reminders.map { reminder in
            guard let change = pending[reminder.id] else { return reminder }
            var updated = reminder
            updated.isCompleted = change.completed
            updated.completedAt = change.completedAt
            return updated
        }
    }

    func addEvent(_ event: ParsedEvent, to calendarID: String) async throws {
        guard let client else { return }
        try await client.addEvent(event, calendarID: calendarID)
        await refresh()
    }

    func addReminder(_ task: ScreenieTask, to listID: String) async throws {
        guard let client else { return }
        try await client.addReminder(title: task.title, dueDate: task.dueDate, notes: task.notes, listID: listID)
        await refresh()
    }
}

enum NewItemDestination: Hashable, Sendable {
    case screenie
    case reminders(String)
    case calendar(String)

    init?(storageValue: String) {
        if storageValue == "screenie" {
            self = .screenie
        } else if storageValue.hasPrefix("reminders:") {
            self = .reminders(String(storageValue.dropFirst("reminders:".count)))
        } else if storageValue.hasPrefix("calendar:") {
            self = .calendar(String(storageValue.dropFirst("calendar:".count)))
        } else {
            return nil
        }
    }

    var storageValue: String {
        switch self {
        case .screenie: "screenie"
        case let .reminders(id): "reminders:\(id)"
        case let .calendar(id): "calendar:\(id)"
        }
    }
}
