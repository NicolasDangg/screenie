import Foundation

struct TaskScheduleSuggestion: Codable, Equatable, Identifiable, Sendable {
    var id: String { "\(taskTitle)-\(start.timeIntervalSinceReferenceDate)" }
    let taskTitle: String
    let start: Date
    let end: Date
    let note: String
}
