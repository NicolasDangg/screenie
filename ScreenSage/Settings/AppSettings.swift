import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let defaultProvider = AIProvider.openRouter

    private enum Keys {
        static let provider = "provider"
        static let model = "model"
        static let followFocusedDisplay = "followFocusedDisplay"

        static func apiKey(for provider: AIProvider) -> String {
            "apiKey.\(provider.rawValue)"
        }
    }

    private let defaults: UserDefaults

    var provider: AIProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: Keys.provider)
            model = provider.defaultModel
            apiKey = defaults.string(forKey: Keys.apiKey(for: provider)) ?? ""
        }
    }
    var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }
    var followFocusedDisplay: Bool {
        didSet { defaults.set(followFocusedDisplay, forKey: Keys.followFocusedDisplay) }
    }
    var apiKey: String
    var savedMessage = ""

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawProvider = defaults.string(forKey: Keys.provider) ?? ""
        let selectedProvider = AIProvider(rawValue: rawProvider) ?? Self.defaultProvider
        provider = selectedProvider
        model = defaults.string(forKey: Keys.model) ?? selectedProvider.defaultModel
        followFocusedDisplay = defaults.object(forKey: Keys.followFocusedDisplay) as? Bool ?? true
        apiKey = defaults.string(forKey: Keys.apiKey(for: selectedProvider)) ?? ""
    }

    func saveAPIKey() {
        apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(apiKey, forKey: Keys.apiKey(for: provider))
        savedMessage = apiKey.isEmpty ? "API key removed" : "API key saved locally"
    }

    func apiKey(for provider: AIProvider) -> String {
        if provider == self.provider { return apiKey }
        return defaults.string(forKey: Keys.apiKey(for: provider)) ?? ""
    }
}
