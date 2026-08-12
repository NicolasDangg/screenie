import Foundation

enum ProviderRequestBuilder {
    static func requestBody(
        provider: AIProvider,
        model: String,
        messages: [ChatMessage],
        ocrText: String = "",
        imageData: Data? = nil
    ) -> [String: Any] {
        var text = messages.map { message in
            "\(message.role == .user ? "User" : "Assistant"): \(message.text)"
        }.joined(separator: "\n\n")
        if !ocrText.isEmpty {
            text += "\n\nText recognized locally from the current screen:\n\(ocrText)"
        }
        let imageURL = imageData.map { "data:image/jpeg;base64,\($0.base64EncodedString())" }

        switch provider {
        case .openAI:
            var content: [[String: Any]] = [["type": "input_text", "text": text]]
            if let imageURL {
                content.append(["type": "input_image", "image_url": imageURL, "detail": "auto"])
            }
            return [
                "model": model,
                "store": false,
                "stream": true,
                "input": [[
                    "role": "user",
                    "content": content
                ]]
            ]
        case .openRouter:
            var content: [[String: Any]] = [["type": "text", "text": text]]
            if let imageURL {
                content.append(["type": "image_url", "image_url": ["url": imageURL]])
            }
            return [
                "model": model,
                "stream": true,
                "messages": [[
                    "role": "user",
                    "content": content
                ]]
            ]
        }
    }
}
