enum PromptSuggestion: String, CaseIterable, Identifiable {
    case explain
    case summarize
    case findBug
    case explainConcept

    var id: Self { self }

    var title: String {
        switch self {
        case .explain: "Explain"
        case .summarize: "Summarize"
        case .findBug: "Find a bug"
        case .explainConcept: "Explain concept"
        }
    }

    var systemImage: String {
        switch self {
        case .explain: "sparkles"
        case .summarize: "text.alignleft"
        case .findBug: "ladybug"
        case .explainConcept: "lightbulb"
        }
    }

    var prompt: String {
        switch self {
        case .explain: "Explain this question"
        case .summarize: "Summarize what is on my screen"
        case .findBug: "Find the bug in the code on my screen and explain the fix"
        case .explainConcept: "Explain the concept on my screen"
        }
    }
}

