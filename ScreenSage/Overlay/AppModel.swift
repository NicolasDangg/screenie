import AppKit
import Observation

@MainActor
@Observable
final class AppModel {
    var prompt = PromptSuggestion.explain.prompt
    var answer = ""
    var errorMessage = ""
    var isWorking = false
    var presentationID = 0

    let settings: AppSettings
    private var requestTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func prepareForPresentation() {
        prompt = PromptSuggestion.explain.prompt
        errorMessage = ""
        presentationID += 1
    }

    func apply(_ suggestion: PromptSuggestion) {
        prompt = suggestion.prompt
        presentationID += 1
    }

    func submit() {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty, !isWorking else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Add an API key in Settings before asking about your screen."
            return
        }

        answer = ""
        errorMessage = ""
        isWorking = true
        let provider = settings.provider
        let model = settings.model
        let apiKey = settings.apiKey

        requestTask?.cancel()
        requestTask = Task {
            defer { isWorking = false }
            do {
                let context = try await ScreenContextCapture.capture()
                for try await delta in ProviderClient().stream(
                    provider: provider,
                    model: model,
                    apiKey: apiKey,
                    prompt: trimmedPrompt,
                    ocrText: context.ocrText,
                    imageData: context.imageData
                ) {
                    try Task.checkCancellation()
                    answer += delta
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}

