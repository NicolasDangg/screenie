import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let taskSources: AppleTaskSources

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView(settings: settings)
            }
            Tab("Tasks", systemImage: "checklist") {
                TaskSourcesSettingsView(sources: taskSources)
            }
        }
        .frame(width: 500)
        .frame(minHeight: 560)
    }
}

private struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var showingModelPicker = false

    var body: some View {
        Form {
            Section("Model") {
                Picker("Provider", selection: $settings.provider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.title).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                if settings.provider == .openRouter {
                    LabeledContent("Model") {
                        Button {
                            showingModelPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(settings.model).lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .popover(isPresented: $showingModelPicker) {
                            OpenRouterModelPicker(settings: settings)
                        }
                    }
                } else {
                    TextField("Model", text: $settings.model)
                }

                LabeledContent("API key") {
                    HStack(spacing: 8) {
                        SecureField("API key", text: $settings.apiKey)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                            .onSubmit(settings.saveAPIKey)
                        Button("Save", action: settings.saveAPIKey)
                    }
                }
                if !settings.savedMessage.isEmpty {
                    Label(settings.savedMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.callout)
                }
            }

            Section("Behavior") {
                Toggle("Open on the display under the pointer", isOn: $settings.followFocusedDisplay)
                LabeledContent("Ask about screen") { KeyCaps(keys: ["⌥", "Space"]) }
                LabeledContent("Open tasks") { KeyCaps(keys: ["⌥", "⌘", "Space"]) }
            }

            PermissionSettingsView()
            UpdateSettingsView(updater: AppUpdater.shared)

            Section {
                Text("Your API key is stored in local app preferences. Screenshots and OCR text are sent with each request but never saved; only prompt and response text is kept for History.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Privacy")
            }
        }
        .formStyle(.grouped)
    }
}

/// Keyboard shortcut keys drawn as small key caps.
private struct KeyCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, key.count > 1 ? 8 : 0)
                    .frame(minWidth: 22, minHeight: 22)
                    .background(.primary.opacity(0.07), in: .rect(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.14)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(keys.joined(separator: " "))
    }
}
