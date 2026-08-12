import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Picker("Provider", selection: $settings.provider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }
            TextField("Model", text: $settings.model)
            SecureField("API key", text: $settings.apiKey)
            HStack {
                Button("Save API Key", action: settings.saveAPIKey)
                Text(settings.savedMessage)
                    .foregroundStyle(.secondary)
            }
            Text("Your key is stored in macOS Keychain. Screenshots and OCR text are kept in memory and sent only to the provider you select when you submit a prompt.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}

