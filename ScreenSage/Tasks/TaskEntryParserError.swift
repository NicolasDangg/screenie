import Foundation

enum TaskEntryParserError: LocalizedError, Equatable {
    case emptyTitle
    case invalidDueDate(String)
    case missingEventTime

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "Enter a task title."
        case .invalidDueDate(let value):
            "Could not understand the due date “\(value)”."
        case .missingEventTime:
            "Add when the event happens, like “Lunch with Sam tomorrow 12–1”."
        }
    }
}
