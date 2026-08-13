import Foundation

struct ScreenieTask: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var title: String
    var dueDate: Date?
    var notes: String
    var isCompleted: Bool
    var createdAt: Date
    var completedAt: Date?
    var calendarEventIdentifier: String?

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        notes: String = "",
        isCompleted: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        calendarEventIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.notes = notes
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.calendarEventIdentifier = calendarEventIdentifier
    }
}
