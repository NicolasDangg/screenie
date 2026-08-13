import Foundation

enum TaskScheduleError: LocalizedError {
    case invalidResponse
    case invalidSuggestion

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "OpenRouter returned an invalid schedule."
        case .invalidSuggestion:
            "OpenRouter returned an invalid study block."
        }
    }
}
