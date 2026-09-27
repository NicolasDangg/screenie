import Foundation

struct OpenRouterModel: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

enum OpenRouterModelCatalog {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/models")!

    /// Fetches the public model list; no API key is needed.
    static func fetch() async throws -> [OpenRouterModel] {
        let (data, response) = try await URLSession.shared.data(from: endpoint)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.requestFailed(String(data: data, encoding: .utf8) ?? "Could not load models")
        }
        return try decode(data)
    }

    /// Keeps only models that accept image input, since every request includes a screenshot.
    static func decode(_ data: Data) throws -> [OpenRouterModel] {
        struct Response: Decodable {
            struct Model: Decodable {
                struct Architecture: Decodable {
                    let input_modalities: [String]?
                }
                let id: String
                let name: String?
                let architecture: Architecture?
            }
            let data: [Model]
        }

        return try JSONDecoder().decode(Response.self, from: data).data
            .filter { $0.architecture?.input_modalities?.contains("image") == true }
            .map { OpenRouterModel(id: $0.id, name: $0.name ?? $0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
