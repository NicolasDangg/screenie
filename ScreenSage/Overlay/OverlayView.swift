import SwiftUI

struct OverlayView: View {
    @Bindable var model: AppModel
    @FocusState private var promptIsFocused: Bool
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OverlayHeaderView(isWorking: model.isWorking, close: close)
            OverlayAnswerView(
                answer: model.answer,
                errorMessage: model.errorMessage,
                isWorking: model.isWorking,
                openScreenRecordingSettings: model.openScreenRecordingSettings
            )
            SuggestionBarView(model: model)
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Ask about your screen", text: $model.prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .focused($promptIsFocused)
                    .onSubmit(model.submit)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.07), in: .rect(cornerRadius: 14))

                Button("Send", systemImage: "arrow.up", action: model.submit)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 10))
                    .controlSize(.large)
                    .frame(height: 34)
                    .disabled(model.isWorking || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: OverlayLayout.width, height: OverlayLayout.height)
        .background {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(red: 0.055, green: 0.06, blue: 0.075).opacity(0.88))
        }
        .glassEffect(.regular.tint(.black.opacity(0.22)), in: .rect(cornerRadius: 26))
        .preferredColorScheme(.dark)
        .task { promptIsFocused = true }
        .onChange(of: model.presentationID) { _, _ in promptIsFocused = true }
    }
}

#Preview {
    OverlayView(model: AppModel(settings: AppSettings()), close: {})
        .padding(40)
}
