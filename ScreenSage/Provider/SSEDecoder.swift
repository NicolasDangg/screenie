import Foundation

enum SSEDecoder {
    static func delta(from dataLine: String, provider: AIProvider) -> String? {
        guard dataLine != "[DONE]", let data = dataLine.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        switch provider {
        case .openAI:
            guard json["type"] as? String == "response.output_text.delta" else { return nil }
            return json["delta"] as? String
        case .openRouter:
            let choices = json["choices"] as? [[String: Any]]
            let delta = choices?.first?["delta"] as? [String: Any]
            return delta?["content"] as? String
        }
    }
}

