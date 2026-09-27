import Foundation

struct OpenRouterModel: Decodable, Identifiable {
    let id: String
    let name: String
    let architecture: Architecture

    struct Architecture: Decodable {
        let inputModalities: [String]
        let outputModalities: [String]

        enum CodingKeys: String, CodingKey {
            case inputModalities = "input_modalities"
            case outputModalities = "output_modalities"
        }
    }

    var supportsScreenChat: Bool {
        architecture.inputModalities.contains("image")
            && architecture.outputModalities.contains("text")
    }
}

enum OpenRouterModelCatalog {
    static func fetch(apiKey: String) async throws -> [OpenRouterModel] {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let catalog = try JSONDecoder().decode(Catalog.self, from: data)
        return catalog.data.filter(\.supportsScreenChat)
    }

    private struct Catalog: Decodable {
        let data: [OpenRouterModel]
    }
}
