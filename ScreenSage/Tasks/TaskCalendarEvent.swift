import Foundation

struct TaskCalendarEvent: Equatable, Sendable {
    let title: String
    let startDate: Date?
    let endDate: Date?
    let notes: String
    let taskMarker: String

    init(task: ScreenieTask) {
        taskMarker = "Task ID: \(task.id.uuidString)"
        title = task.isCompleted ? "✓ \(task.title)" : task.title
        startDate = task.dueDate
        endDate = task.dueDate?.addingTimeInterval(30 * 60)
        notes = task.notes.isEmpty
            ? "Managed by screenie\n\(taskMarker)"
            : "\(task.notes)\n\nManaged by screenie\n\(taskMarker)"
    }
}
