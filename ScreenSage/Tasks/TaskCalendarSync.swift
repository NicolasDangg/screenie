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
