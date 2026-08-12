import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    private enum Keys {
        static let provider = "provider"
        static let model = "model"
    }

    var provider: AIProvider {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider)
            model = provider.defaultModel
            apiKey = KeychainStore.read(account: provider.rawValue)
        }
    }
    var model: String {
        didSet { UserDefaults.standard.set(model, forKey: Keys.model) }
    }
    var apiKey: String
    var savedMessage = ""

    init() {
        let rawProvider = UserDefaults.standard.string(forKey: Keys.provider) ?? ""
        let selectedProvider = AIProvider(rawValue: rawProvider) ?? .openAI
        provider = selectedProvider
        model = UserDefaults.standard.string(forKey: Keys.model) ?? selectedProvider.defaultModel
        apiKey = KeychainStore.read(account: selectedProvider.rawValue)
    }

    func saveAPIKey() {
        do {
            try KeychainStore.save(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), account: provider.rawValue)
            savedMessage = apiKey.isEmpty ? "API key removed" : "API key saved in Keychain"
        } catch {
            savedMessage = "Could not save API key: \(error.localizedDescription)"
        }
    }
}

