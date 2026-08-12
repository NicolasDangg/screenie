import Foundation

enum AIProvider: String, CaseIterable, Identifiable {
    case openAI
    case openRouter

    var id: Self { self }

    var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .openRouter: "OpenRouter"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-4.1-mini"
        case .openRouter: "openai/gpt-4.1-mini"
        }
    }

    var endpoint: URL {
        switch self {
        case .openAI: URL(string: "https://api.openai.com/v1/responses")!
        case .openRouter: URL(string: "https://openrouter.ai/api/v1/chat/completions")!
        }
    }
}

