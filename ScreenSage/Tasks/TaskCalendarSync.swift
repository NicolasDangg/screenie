import EventKit
import Foundation

actor TaskCalendarSync {
    static let shared = TaskCalendarSync()

    private let eventStore = EKEventStore()

    func upsert(_ task: ScreenieTask) async throws -> String? {
        let descriptor = TaskCalendarEvent(task: task)
        guard let startDate = descriptor.startDate,
              let endDate = descriptor.endDate else { return nil }
        guard try await hasAccess() else {
            throw NSError(
                domain: "screenie.calendar",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Calendar access was not granted."]
            )
        }

        try Task.checkCancellation()
        let event = task.calendarEventIdentifier.flatMap(eventStore.event(withIdentifier:))
            ?? matchingEvent(marker: descriptor.taskMarker, near: startDate)
            ?? EKEvent(eventStore: eventStore)
        guard let calendar = event.calendar ?? eventStore.defaultCalendarForNewEvents else {
            throw NSError(
                domain: "screenie.calendar",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No writable default calendar is available."]
            )
        }

        event.calendar = calendar
        event.title = descriptor.title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = descriptor.notes
        try Task.checkCancellation()
        try eventStore.save(event, span: .thisEvent, commit: true)
        return event.eventIdentifier
    }

    func delete(_ task: ScreenieTask) async throws {
        let descriptor = TaskCalendarEvent(task: task)
        guard let dueDate = descriptor.startDate else { return }
        guard try await hasAccess() else {
            throw NSError(
                domain: "screenie.calendar",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Calendar access was not granted."]
            )
        }

        guard let event = task.calendarEventIdentifier.flatMap(eventStore.event(withIdentifier:))
                ?? matchingEvent(marker: descriptor.taskMarker, near: dueDate) else { return }
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }

    /// Reads the task's linked event without prompting for access.
    func linkedEvent(for task: ScreenieTask) -> LinkedCalendarEventLookup {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess,
              let identifier = task.calendarEventIdentifier else { return .unknown }
        let marker = TaskCalendarEvent(task: task).taskMarker
        // Identifiers can change when an account resyncs, so fall back to the marker before calling it deleted.
        guard let event = eventStore.event(withIdentifier: identifier)
                ?? task.dueDate.flatMap({ matchingEvent(marker: marker, near: $0) }) else { return .missing }
        guard event.notes?.contains(marker) == true, let start = event.startDate else { return .unknown }
        return .found(LinkedCalendarEvent(title: event.title ?? "", start: start, notes: event.notes))
    }

    func add(_ schedule: TaskSchedule) async throws {
        guard !schedule.suggestions.isEmpty else { return }
        guard try await hasAccess() else {
            throw NSError(
                domain: "screenie.calendar",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Calendar access was not granted."]
            )
        }
        guard let calendar = eventStore.defaultCalendarForNewEvents else {
            throw NSError(
                domain: "screenie.calendar",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "No writable default calendar is available."]
            )
        }

        do {
            for suggestion in schedule.suggestions {
                try Task.checkCancellation()
                let descriptor = TaskScheduleCalendarEvent(suggestion: suggestion)
                guard matchingEvent(marker: descriptor.marker, near: descriptor.startDate) == nil else { continue }
                let event = EKEvent(eventStore: eventStore)
                event.calendar = calendar
                event.title = descriptor.title
                event.startDate = descriptor.startDate
                event.endDate = descriptor.endDate
                event.notes = descriptor.notes
                try eventStore.save(event, span: .thisEvent, commit: false)
            }
            try eventStore.commit()
        } catch {
            eventStore.reset()
            throw error
        }
    }

    private func matchingEvent(marker: String, near date: Date) -> EKEvent? {
        let predicate = eventStore.predicateForEvents(
            withStart: date.addingTimeInterval(-24 * 60 * 60),
            end: date.addingTimeInterval(24 * 60 * 60),
            calendars: nil
        )
        return eventStore.events(matching: predicate).first { $0.notes?.contains(marker) == true }
    }

    private func hasAccess() async throws -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            true
        case .notDetermined:
            try await eventStore.requestFullAccessToEvents()
        default:
            false
        }
    }
}

struct TaskScheduleCalendarEvent: Equatable, Sendable {
    let title: String
    let startDate: Date
    let endDate: Date
    let notes: String
    let marker: String

    init(suggestion: TaskScheduleSuggestion) {
        title = "Study: \(suggestion.taskTitle)"
        startDate = suggestion.start
        endDate = suggestion.end
        marker = "Schedule suggestion: \(suggestion.id)"
        notes = "\(suggestion.note)\n\nSuggested by screenie\n\(marker)"
    }
}
