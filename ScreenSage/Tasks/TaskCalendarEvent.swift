import Foundation

/// The Calendar copy of a screenie task, as screenie writes it.
struct TaskCalendarEvent: Equatable, Sendable {
    static let completedPrefix = "✓ "
    let title: String
    let startDate: Date?
    let endDate: Date?
    let notes: String
    let taskMarker: String

    init(task: ScreenieTask) {
        taskMarker = "Task ID: \(task.id.uuidString)"
        title = task.isCompleted ? "\(Self.completedPrefix)\(task.title)" : task.title
        startDate = task.dueDate
        endDate = task.dueDate?.addingTimeInterval(30 * 60)
        notes = task.notes.isEmpty
            ? "Managed by screenie\n\(taskMarker)"
            : "\(task.notes)\n\nManaged by screenie\n\(taskMarker)"
    }
}

/// What a linked Calendar event currently says, for pulling edits made in Calendar back into the task.
struct LinkedCalendarEvent: Equatable, Sendable {
    let title: String
    let start: Date
    let notes: String?
}

enum LinkedCalendarEventLookup: Equatable, Sendable {
    case found(LinkedCalendarEvent)
    /// The event was deleted in Calendar.
    case missing
    /// No access or no link, so nothing can be said about the event.
    case unknown
}

extension TaskCalendarEvent {
    /// Applies edits made to the Calendar copy: title, start time, and notes above screenie's marker.
    /// Completion stays screenie's, so a stray or missing ✓ never changes it.
    static func applying(_ event: LinkedCalendarEvent, to task: ScreenieTask) -> ScreenieTask {
        var updated = task
        var title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.hasPrefix(completedPrefix) { title.removeFirst(completedPrefix.count) }
        if !title.isEmpty { updated.title = title }
        updated.dueDate = event.start
        let notes = event.notes ?? ""
        let userNotes = notes.range(of: TaskAgenda.screenieEventMarker).map { String(notes[..<$0.lowerBound]) } ?? notes
        updated.notes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return updated
    }
}
