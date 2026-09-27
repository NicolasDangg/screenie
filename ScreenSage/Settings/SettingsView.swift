import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var openRouterModels: [OpenRouterModel] = []
    @State private var modelFilter = ""
    @State private var modelLoadError: String?

    var body: some View {
        Form {
            Picker("Provider", selection: $settings.provider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }
            if settings.provider == .openRouter {
                openRouterModelPicker
            }
            TextField("Model ID", text: $settings.model)
            SecureField("API key", text: $settings.apiKey)
            HStack {
                Button("Save API Key", action: settings.saveAPIKey)
                Text(settings.savedMessage)
                    .foregroundStyle(.secondary)
            }
            PermissionSettingsView()
            Text("Your key is stored in local app preferences. Screenshots and OCR text are transient request context and are never saved. Prompt and response text is stored locally in Application Support for History.")
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460)
        .task(id: settings.provider) {
            guard settings.provider == .openRouter, openRouterModels.isEmpty else { return }
            await loadOpenRouterModels()
        }
    }

    @ViewBuilder
    private var openRouterModelPicker: some View {
        if let modelLoadError {
            HStack {
                Text(modelLoadError)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Retry") { Task { await loadOpenRouterModels() } }
            }
        } else if openRouterModels.isEmpty {
            LabeledContent("Model") { ProgressView().controlSize(.small) }
        } else {
            TextField("Filter models", text: $modelFilter)
            Picker("Model", selection: $settings.model) {
                ForEach(pickerModels) { model in
                    Text(model.name).tag(model.id)
                }
            }
        }
    }

    /// Filtered models, always keeping the current selection so the picker never loses it.
    private var pickerModels: [OpenRouterModel] {
        let query = modelFilter.trimmingCharacters(in: .whitespaces)
        var models = query.isEmpty ? openRouterModels : openRouterModels.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query)
        }
        if !models.contains(where: { $0.id == settings.model }) {
            let current = openRouterModels.first { $0.id == settings.model }
            models.insert(current ?? OpenRouterModel(id: settings.model, name: settings.model), at: 0)
        }
        return models
    }

    private func loadOpenRouterModels() async {
        modelLoadError = nil
        do {
            openRouterModels = try await OpenRouterModelCatalog.fetch()
        } catch {
            modelLoadError = "Couldn't load OpenRouter models"
        }
    }
}
