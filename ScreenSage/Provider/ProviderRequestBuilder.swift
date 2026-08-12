import Foundation

enum ProviderRequestBuilder {
    static func requestBody(
        provider: AIProvider,
        model: String,
        prompt: String,
        ocrText: String,
        imageData: Data
    ) -> [String: Any] {
        let text = ocrText.isEmpty
            ? prompt
            : "\(prompt)\n\nText recognized locally from the screen:\n\(ocrText)"
        let imageURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"

        switch provider {
        case .openAI:
            return [
                "model": model,
                "store": false,
                "stream": true,
                "input": [[
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": text],
                        ["type": "input_image", "image_url": imageURL, "detail": "auto"]
                    ]
                ]]
            ]
        case .openRouter:
            return [
                "model": model,
                "stream": true,
                "messages": [[
                    "role": "user",
                    "content": [
                        ["type": "text", "text": text],
                        ["type": "image_url", "image_url": ["url": imageURL]]
                    ]
                ]]
            ]
        }
    }
}

