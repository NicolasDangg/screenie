import Foundation

enum TaskEntryParserError: LocalizedError, Equatable {
    case emptyTitle
    case invalidDueDate(String)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            "Enter a task title."
        case .invalidDueDate(let value):
            "Could not understand the due date “\(value)”."
        }
    }
}
