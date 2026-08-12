import SwiftUI

struct SuggestionBarView: View {
    @Bindable var model: AppModel

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(PromptSuggestion.allCases) { suggestion in
                    Button(suggestion.title, systemImage: suggestion.systemImage) {
                        model.apply(suggestion)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                }
            }
        }
    }
}

