import Foundation

enum TaskAgendaKind: Equatable, Sendable {
    case task
    case reminder
    case event
}

/// One row in the task views, from screenie, Apple Reminders, or Apple Calendar.
struct TaskAgendaItem: Identifiable, Equatable {
    enum Source: Equatable {
        case task(ScreenieTask)
        case reminder(AppleReminderItem)
        case event(AppleEventItem)
    }

    let source: Source
    let id: String
    let title: String
    let date: Date?
    let endDate: Date?
    let hasTime: Bool
    let isCompleted: Bool
    let completedAt: Date?
    let sourceName: String
    /// `nil` means the app accent color.
    let color: SourceColor?

    init(_ task: ScreenieTask) {
        source = .task(task)
        id = "task-\(task.id.uuidString)"
        title = task.title
        date = task.dueDate
        endDate = nil
        hasTime = task.dueDate != nil
        isCompleted = task.isCompleted
        completedAt = task.completedAt
        sourceName = "screenie"
        color = nil
    }

    init(_ reminder: AppleReminderItem) {
        source = .reminder(reminder)
        id = "reminder-\(reminder.id)"
        title = reminder.title
        date = reminder.dueDate
        endDate = nil
        hasTime = reminder.hasTime
        isCompleted = reminder.isCompleted
        completedAt = reminder.completedAt
        sourceName = reminder.list.title
        color = reminder.list.color
    }

    init(_ event: AppleEventItem) {
        source = .event(event)
        id = "event-\(event.id)"
        title = event.title
        date = event.start
        endDate = event.end
        hasTime = !event.isAllDay
        isCompleted = false
        completedAt = nil
        sourceName = event.calendar.title
        color = event.calendar.color
    }

    var kind: TaskAgendaKind {
        switch source {
        case .task: .task
        case .reminder: .reminder
        case .event: .event
        }
    }

    var task: ScreenieTask? {
        if case let .task(task) = source { task } else { nil }
    }
}

enum TaskAgendaFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case screenie = "screenie"
    case reminders = "Reminders"
    case events = "Events"

    var id: Self { self }

    func includes(_ kind: TaskAgendaKind) -> Bool {
        switch self {
        case .all: true
        case .screenie: kind == .task
        case .reminders: kind == .reminder
        case .events: kind == .event
        }
    }
}

struct TaskAgendaSection: Identifiable, Equatable {
    enum Kind: Equatable {
        case overdue
        case day(Date)
        case later
        case someday
    }

    let kind: Kind
    let title: String
    var items: [TaskAgendaItem]

    var id: String { title }
}

enum TaskAgenda {
    static let screenieEventMarker = "Managed by screenie"

    /// screenie mirrors dated tasks into Calendar; those copies must not show up twice.
    static func isManagedByScreenie(notes: String?) -> Bool {
        notes?.contains(screenieEventMarker) == true
    }

    static func items(
        tasks: [ScreenieTask],
        reminders: [AppleReminderItem],
        events: [AppleEventItem]
    ) -> [TaskAgendaItem] {
        tasks.map(TaskAgendaItem.init) + reminders.map(TaskAgendaItem.init) + events.map(TaskAgendaItem.init)
    }

    /// Groups items for the list view: overdue, each of the next seven days, later, and undated.
    /// Completed items only appear on the day they were completed, and events only for today and tomorrow.
    static func listSections(
        _ items: [TaskAgendaItem],
        filter: TaskAgendaFilter,
        now: Date,
        calendar: Calendar
    ) -> [TaskAgendaSection] {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) else { return [] }

        var overdue: [TaskAgendaItem] = []
        var days: [Date: [TaskAgendaItem]] = [:]
        var later: [TaskAgendaItem] = []
        var someday: [TaskAgendaItem] = []

        for item in items where filter.includes(item.kind) {
            if item.isCompleted, !(item.completedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false) {
                continue
            }
            guard let date = item.date else {
                if item.kind != .event { someday.append(item) }
                continue
            }
            if item.kind == .event {
                let end = item.endDate ?? date
                guard end > today, date < dayAfterTomorrow else { continue }
                days[max(calendar.startOfDay(for: date), today), default: []].append(item)
                continue
            }
            if date < today {
                if item.isCompleted { days[today, default: []].append(item) } else { overdue.append(item) }
            } else if date < weekEnd {
                days[calendar.startOfDay(for: date), default: []].append(item)
            } else {
                later.append(item)
            }
        }

        var sections: [TaskAgendaSection] = []
        if !overdue.isEmpty {
            sections.append(TaskAgendaSection(kind: .overdue, title: "Overdue", items: sorted(overdue, untimedFirst: false)))
        }
        for day in days.keys.sorted() {
            let title = if day == today {
                "Today"
            } else if day == tomorrow {
                "Tomorrow"
            } else {
                day.formatted(.dateTime.weekday(.wide))
            }
            sections.append(TaskAgendaSection(kind: .day(day), title: title, items: sorted(days[day] ?? [])))
        }
        if !later.isEmpty {
            sections.append(TaskAgendaSection(kind: .later, title: "Later", items: sorted(later, untimedFirst: false)))
        }
        if !someday.isEmpty {
            let byTitle = someday.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            sections.append(TaskAgendaSection(kind: .someday, title: "Someday", items: byTitle))
        }
        return sections
    }

    /// Items that fall on `day`: untimed ones first, then by start time.
    static func dayItems(_ items: [TaskAgendaItem], on day: Date, calendar: Calendar) -> [TaskAgendaItem] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return sorted(items.filter { item in
            guard let date = item.date else { return false }
            if item.kind == .event {
                return date < end && (item.endDate ?? date) > start
            }
            return date >= start && date < end
        })
    }

    static func weekDates(containing date: Date, calendar: Calendar) -> [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private static func sorted(_ items: [TaskAgendaItem], untimedFirst: Bool = true) -> [TaskAgendaItem] {
        items.sorted { lhs, rhs in
            if untimedFirst, lhs.hasTime != rhs.hasTime { return !lhs.hasTime }
            switch (lhs.date, rhs.date) {
            case let (l?, r?) where l != r: return l < r
            default: return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }
}
