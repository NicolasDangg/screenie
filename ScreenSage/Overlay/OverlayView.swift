import SwiftUI

struct OverlayView: View {
    @Bindable var model: AppModel
    @FocusState private var promptIsFocused: Bool
    let close: () -> Void
    let setExpanded: (Bool) -> Void

    private var isExpanded: Bool { model.isExpanded }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                OverlayAnswerView(
                    messages: model.conversation.messages,
                    streamingResponse: model.streamingResponse,
                    errorMessage: model.errorMessage,
                    isWorking: model.isWorking
                )
                Divider().opacity(0.35)
            }

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)

                TextField("Ask about your screen", text: $model.prompt)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($promptIsFocused)
                    .onSubmit(model.submit)

                Button("Send", systemImage: "arrow.up", action: model.submit)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                    .background(.blue, in: .circle)
                    .foregroundStyle(.white)
                    .opacity(model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
                    .disabled(model.isWorking || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 9)
            .frame(height: OverlayLayout.collapsedHeight)
        }
        .frame(
            width: OverlayLayout.width,
            height: isExpanded ? OverlayLayout.expandedHeight : OverlayLayout.collapsedHeight
        )
        .background(PanelDragArea())
        .background {
            RoundedRectangle(cornerRadius: isExpanded ? 22 : OverlayLayout.collapsedHeight / 2)
                .fill(Color(red: 0.055, green: 0.06, blue: 0.075).opacity(0.9))
        }
        .glassEffect(
            .regular.tint(.black.opacity(0.18)),
            in: .rect(cornerRadius: isExpanded ? 22 : OverlayLayout.collapsedHeight / 2)
        )
        .clipShape(.rect(cornerRadius: isExpanded ? 22 : OverlayLayout.collapsedHeight / 2))
        .preferredColorScheme(.dark)
        .onExitCommand(perform: close)
        .onChange(of: isExpanded, initial: true) { _, expanded in
            setExpanded(expanded)
        }
        .task { promptIsFocused = true }
        .onChange(of: model.presentationID) { _, _ in promptIsFocused = true }
    }
}

#Preview {
    OverlayView(
        model: AppModel(settings: AppSettings()),
        close: {},
        setExpanded: { _ in }
    )
    .padding(40)
}
