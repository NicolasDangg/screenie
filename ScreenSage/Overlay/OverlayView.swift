import AppKit
import SwiftUI

struct OverlayView: View {
    @Bindable var model: AppModel
    @FocusState private var promptIsFocused: Bool
    @State private var showingModelPicker = false
    let close: () -> Void
    let setExpanded: (Bool) -> Void
    let resize: (OverlayResizeHandle, CGPoint) -> Void
    let endResize: () -> Void
    var showHistory: () -> Void = {}

    private var isExpanded: Bool { model.isExpanded }
    private var width: Double {
        model.presentationMode == .tasks ? OverlayLayout.width
            : (isExpanded ? model.expandedChatSize.width : OverlayLayout.collapsedWidth)
    }
    private var height: Double {
        model.presentationMode == .tasks
            ? OverlayLayout.taskHeight
            : (isExpanded ? model.expandedChatSize.height : OverlayLayout.collapsedHeight)
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.presentationMode == .tasks {
                TaskManagerView(model: model)
            } else {
                chatContent
            }
        }
        .frame(width: width, height: height)
        .background(PanelDragArea())
        // A light wash of the window background makes the glass about 20% less see-through.
        // Drawn as a shape so it can't spill into the panel's safe area as a square backdrop.
        .background {
            RoundedRectangle(cornerRadius: OverlayLayout.cornerRadius)
                .fill(.background.opacity(0.2))
        }
        .clipShape(.rect(cornerRadius: OverlayLayout.cornerRadius))
        .glassEffect(.regular, in: .rect(cornerRadius: OverlayLayout.cornerRadius))
        .overlay { if model.presentationMode == .chat && isExpanded { resizeHandles } }
        .onExitCommand(perform: close)
        .onChange(of: isExpanded, initial: true) { _, expanded in setExpanded(expanded) }
        .onChange(of: model.presentationMode) { _, _ in setExpanded(isExpanded) }
        .task { promptIsFocused = model.presentationMode == .chat }
        .onChange(of: model.presentationID) { _, _ in
            promptIsFocused = model.presentationMode == .chat
        }
    }

    private var resizeHandles: some View {
        GeometryReader { geometry in
            let corner = 14.0
            let edge = 6.0
            let sideHeight = geometry.size.height - corner * 2
            resizeHandle(.left, width: edge, height: sideHeight)
                .position(x: edge / 2, y: geometry.size.height / 2)
            resizeHandle(.right, width: edge, height: sideHeight)
                .position(x: geometry.size.width - edge / 2, y: geometry.size.height / 2)
            resizeHandle(.topLeft, width: corner, height: corner)
                .position(x: corner / 2, y: corner / 2)
            resizeHandle(.topRight, width: corner, height: corner)
                .position(x: geometry.size.width - corner / 2, y: corner / 2)
            resizeHandle(.bottomLeft, width: corner, height: corner)
                .position(x: corner / 2, y: geometry.size.height - corner / 2)
            resizeHandle(.bottomRight, width: corner, height: corner)
                .position(x: geometry.size.width - corner / 2, y: geometry.size.height - corner / 2)
        }
    }

    private func resizeHandle(_ handle: OverlayResizeHandle, width: CGFloat, height: CGFloat) -> some View {
        Color.clear
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    let position: NSCursor.FrameResizePosition = switch handle {
                    case .left: .left
                    case .right: .right
                    case .topLeft: .topLeft
                    case .topRight: .topRight
                    case .bottomLeft: .bottomLeft
                    case .bottomRight: .bottomRight
                    }
                    NSCursor.frameResize(position: position, directions: .all).set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { resize(handle, $0.location) }
                .onEnded { _ in endResize() })
    }

    private var chatContent: some View {
        VStack(spacing: 0) {
            if isExpanded {
                HStack(spacing: 8) {
                    Text(model.hasCompletedFirstResponse ? model.conversation.title : "New conversation")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(model.hasCompletedFirstResponse ? .primary : .secondary)
                    Spacer()
                    Button("History", systemImage: "clock", action: showHistory)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                        .help("History")
                    Button("New Chat", systemImage: "plus", action: model.startNewConversation)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.primary.opacity(0.06), in: .rect(cornerRadius: 8))
                        .contentShape(.rect)
                        .help("New Chat")
                }
                .padding(.leading, OverlayLayout.contentInset)
                .padding(.trailing, 12)
                .frame(height: 44)
                Divider().opacity(0.35)
                OverlayAnswerView(
                    messages: model.conversation.messages,
                    streamingResponse: model.streamingResponse,
                    errorMessage: model.errorMessage,
                    workPhase: model.workPhase,
                    attachedScreenshot: model.attachedScreenshot,
                    askAgain: model.askAgainWithNewScreenshot
                )
                Divider().opacity(0.35)
            }
            composer
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if model.prompt.isEmpty {
                    Text(model.hasCompletedFirstResponse ? "Ask a follow-up…" : "Ask about your screen…")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $model.prompt)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    // Cancel NSTextView's built-in line padding so typed text aligns with the inset.
                    .padding(.horizontal, -5)
                    .focused($promptIsFocused)
                    .accessibilityLabel("Message")
                    .onKeyPress(keys: [.return]) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        model.submit()
                        return .handled
                    }
            }
            // Nudge the text down without changing the composer's outer margins or the footer's position.
            .frame(height: 30)
            .padding(.top, 4)
            composerFooter
        }
        .padding(.horizontal, OverlayLayout.contentInset)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(height: OverlayLayout.collapsedHeight)
    }

    private var composerFooter: some View {
        HStack(spacing: 6) {
            // The first message always includes a screenshot, so the toggle only appears for follow-ups.
            if model.hasCompletedFirstResponse {
                screenshotToggle
            }
            modelControl
            Spacer()
            if model.isWorking {
                Text("⌘. to stop")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Stop", systemImage: "stop.fill", action: model.stopResponse)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.system(size: 9))
                    .frame(width: 26, height: 26)
                    .background(.primary.opacity(0.14), in: .circle)
                    .keyboardShortcut(".", modifiers: .command)
                    .help("Stop response")
            } else {
                Text("⌘↵")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Send", systemImage: "arrow.up", action: model.submit)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(canSend ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary.opacity(0.1)), in: .circle)
                    .foregroundStyle(canSend ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .disabled(!canSend)
            }
        }
    }

    private var canSend: Bool {
        !model.isWorking && !model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var screenshotToggle: some View {
        let isOn = model.includeScreenshotForNextMessage
        return Button(action: model.toggleScreenshotForNextMessage) {
            Label("Include screenshot", systemImage: isOn ? "dot.viewfinder" : "viewfinder")
                .labelStyle(.iconOnly)
                .font(.system(size: 14))
                .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 24, height: 24)
                .background(isOn ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 7))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.leading, -4)
        .disabled(!model.canToggleScreenshot)
        .help(isOn ? "Next message includes a new screenshot" : "Include a new screenshot with next message")
        .accessibilityValue(isOn ? "On" : "Off")
    }

    @ViewBuilder private var modelControl: some View {
        if model.settings.provider == .openRouter {
            Button { showingModelPicker = true } label: {
                HStack(spacing: 4) {
                    Text(model.settings.model.split(separator: "/").last.map(String.init) ?? model.settings.model)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingModelPicker) {
                OpenRouterModelPicker(settings: model.settings)
            }
        } else {
            Text(model.settings.model)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct OpenRouterModelPicker: View {
    @Bindable var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var models: [OpenRouterModel] = []
    @State private var error = ""

    private var matches: [OpenRouterModel] {
        models.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                || $0.id.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OpenRouter models")
                .font(.headline)
            TextField("Search models", text: $search)
                .textFieldStyle(.roundedBorder)
            if !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(.secondary)
            } else if models.isEmpty {
                ProgressView("Loading models…")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(matches) { item in
                        Button {
                            settings.model = item.id
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.system(size: 13, weight: .medium))
                                    Text(item.id).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if item.id == settings.model { Image(systemName: "checkmark") }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("Models that accept screenshots and return text")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 340, height: 370)
        .task {
            do {
                models = try await OpenRouterModelCatalog.fetch(apiKey: settings.apiKey)
            } catch {
                self.error = "Could not load models: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    OverlayView(model: AppModel(settings: AppSettings()), close: {}, setExpanded: { _ in }, resize: { _, _ in }, endResize: {})
        .padding(40)
}
