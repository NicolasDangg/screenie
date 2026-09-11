import SwiftUI

struct OverlayView: View {
    @Bindable var model: AppModel
    @FocusState private var promptIsFocused: Bool
    let close: () -> Void
    let setExpanded: (Bool) -> Void

    private var isExpanded: Bool { model.isExpanded }
    private var height: Double {
        model.presentationMode == .tasks
            ? OverlayLayout.taskHeight
            : (isExpanded ? OverlayLayout.expandedHeight : OverlayLayout.collapsedHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.presentationMode == .tasks {
                TaskManagerView(model: model)
            } else {
                if isExpanded {
                    ZStack(alignment: .topTrailing) {
                        OverlayAnswerView(
                            messages: model.conversation.messages,
                            streamingResponse: model.streamingResponse,
                            errorMessage: model.errorMessage,
                            isWorking: model.isWorking,
                            includesScreenContext: model.includeScreenshotForNextMessage
                        )
                        .padding(.top, OverlayLayout.controlDiameter + 8)

                        Button("New Chat", systemImage: "plus", action: model.startNewConversation)
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(
                                width: OverlayLayout.controlDiameter,
                                height: OverlayLayout.controlDiameter
                            )
                            .background(.primary.opacity(0.08), in: .circle)
                            .overlay {
                                Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 0.8)
                            }
                            .help("New Chat")
                            .padding(.top, 8)
                            .padding(.trailing, 14.1)
                    }
                    Divider().opacity(0.35)
                }

                HStack(spacing: 6) {
                    Button(action: model.toggleScreenshotForNextMessage) {
                        ZStack {
                            Circle()
                                .fill(model.includeScreenshotForNextMessage ? .blue : .clear)
                            Circle()
                                .strokeBorder(.primary.opacity(0.34), lineWidth: 0.8)
                            if model.includeScreenshotForNextMessage {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(
                        width: OverlayLayout.controlDiameter,
                        height: OverlayLayout.controlDiameter
                    )
                    .foregroundStyle(model.includeScreenshotForNextMessage ? .white : .primary)
                    .opacity(model.canToggleScreenshot ? 1 : 0.45)
                    .disabled(!model.canToggleScreenshot)
                    .accessibilityLabel(
                        model.includeScreenshotForNextMessage ? "Screenshot included" : "Screenshot excluded"
                    )
                    .accessibilityValue(model.includeScreenshotForNextMessage ? "On" : "Off")
                    .accessibilityHint("Toggles whether the next message includes a new screenshot and OCR")

                    TextField("Ask about your screen", text: $model.prompt)
                        .textFieldStyle(.plain)
                        .lineLimit(1)
                        .focused($promptIsFocused)
                        .onSubmit(model.submit)

                    Button("Send", systemImage: "arrow.up", action: model.submit)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .frame(
                            width: OverlayLayout.controlDiameter,
                            height: OverlayLayout.controlDiameter
                        )
                        .background(.blue, in: .circle)
                        .foregroundStyle(.white)
                        .opacity(model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1)
                        .disabled(model.isWorking || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 14.1)
                .frame(height: OverlayLayout.collapsedHeight)
            }
        }
        .frame(
            width: OverlayLayout.width,
            height: height
        )
        .background(PanelDragArea())
        .background { LiveBackdropView().allowsHitTesting(false) }
        .clipShape(.rect(cornerRadius: OverlayLayout.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .primary.opacity(0.12), .white.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.9
                )
                .allowsHitTesting(false)
        }
        .onExitCommand(perform: close)
        .onChange(of: isExpanded, initial: true) { _, expanded in
            setExpanded(expanded)
        }
        .onChange(of: model.presentationMode) { _, _ in
            setExpanded(isExpanded)
        }
        .task { promptIsFocused = model.presentationMode == .chat }
        .onChange(of: model.presentationID) { _, _ in
            promptIsFocused = model.presentationMode == .chat
        }
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
