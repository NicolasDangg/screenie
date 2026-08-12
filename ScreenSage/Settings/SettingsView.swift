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
            PermissionSettingsView()
            Text("Your key is stored in macOS Keychain. Screenshots and OCR text are transient request context and are never saved. Prompt and response text is stored locally in Application Support for History.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
    }
}
