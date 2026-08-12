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

            HStack(spacing: 6) {
                TextField("Ask about your screen", text: $model.prompt)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($promptIsFocused)
                    .onSubmit(model.submit)

                Button("Send", systemImage: "arrow.up", action: model.submit)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .frame(width: 25.2, height: 25.2)
                    .background(.blue, in: .circle)
                    .foregroundStyle(.white)
                    .opacity(model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
                    .disabled(model.isWorking || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 8.1)
            .frame(height: OverlayLayout.collapsedHeight)
        }
        .frame(
            width: OverlayLayout.width,
            height: isExpanded ? OverlayLayout.expandedHeight : OverlayLayout.collapsedHeight
        )
        .background(PanelDragArea())
        .glassEffect(
            .regular,
            in: .rect(cornerRadius: isExpanded ? 20 : OverlayLayout.collapsedHeight / 2)
        )
        .clipShape(.rect(cornerRadius: isExpanded ? 20 : OverlayLayout.collapsedHeight / 2))
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
