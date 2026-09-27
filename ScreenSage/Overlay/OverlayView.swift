import AppKit
import SwiftUI

struct OverlayView: View {
    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var promptIsFocused: Bool
    @State private var showingModelPicker = false
    let close: () -> Void
    let setExpanded: (Bool) -> Void
    let resize: (OverlayResizeHandle, CGPoint) -> Void
    let endResize: () -> Void

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
            let sideHeight = geometry.size.height - 32 - (model.attachedScreenshot == nil
                ? OverlayLayout.collapsedHeight : OverlayLayout.attachedComposerHeight)
            resizeHandle(.left, width: 18, height: sideHeight)
                .position(x: 9, y: 32 + sideHeight / 2)
            resizeHandle(.right, width: 18, height: sideHeight)
                .position(x: geometry.size.width - 9, y: 32 + sideHeight / 2)
            resizeHandle(.topLeft, width: 32, height: 32)
                .position(x: 16, y: 16)
            resizeHandle(.topRight, width: 32, height: 32)
                .position(x: geometry.size.width - 16, y: 16)
            resizeHandle(.bottomLeft, width: 32, height: 32)
                .position(x: 16, y: geometry.size.height - 16)
            resizeHandle(.bottomRight, width: 32, height: 32)
                .position(x: geometry.size.width - 16, y: geometry.size.height - 16)
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
                HStack {
                    Text(model.conversation.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("New Chat", systemImage: "plus", action: model.startNewConversation)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .help("New Chat")
                }
                .padding(.horizontal, 34)
                .padding(.top, 14)
                OverlayAnswerView(
                    messages: model.conversation.messages,
                    streamingResponse: model.streamingResponse,
                    errorMessage: model.errorMessage,
                    isWorking: model.isWorking,
                    includesScreenContext: model.includeScreenshotForNextMessage
                )
                Divider().opacity(0.35)
            }
            composer
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 4) {
            attachment
            ZStack(alignment: .topLeading) {
                if model.prompt.isEmpty {
                    Text("Ask about your screen…")
                        .foregroundStyle(.secondary)
                        .padding(.top, 5)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $model.prompt)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .focused($promptIsFocused)
                    .accessibilityLabel("Message")
                    .onKeyPress(keys: [.return]) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        model.submit()
                        return .handled
                    }
            }
            .frame(height: 34)
            composerFooter
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(height: model.attachedScreenshot == nil
               ? OverlayLayout.collapsedHeight : OverlayLayout.attachedComposerHeight)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.attachedScreenshot != nil)
    }

    @ViewBuilder private var attachment: some View {
        if let data = model.attachedScreenshot, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 31)
                .clipShape(.rect(cornerRadius: 7))
                .accessibilityLabel("Screenshot sent with latest prompt")
                .help("Screenshot sent with latest prompt")
                .transition(reduceMotion ? .identity : .move(edge: .top).combined(with: .opacity))
        }
    }

    private var composerFooter: some View {
        HStack(spacing: 8) {
            Button(action: model.toggleScreenshotForNextMessage) {
                Label("Include screenshot", systemImage: model.includeScreenshotForNextMessage
                      ? "camera.fill" : "camera")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(model.includeScreenshotForNextMessage ? .blue : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!model.canToggleScreenshot)
            .help(model.canToggleScreenshot
                  ? "Include screenshot with next message"
                  : "The first message includes a screenshot")
            .accessibilityValue(model.includeScreenshotForNextMessage ? "On" : "Off")

            modelControl
            Spacer()
            Text("⌘↵")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Button("Send", systemImage: "arrow.up", action: model.submit)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
                .background(.blue, in: .circle)
                .foregroundStyle(.white)
                .disabled(model.isWorking || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(model.isWorking || model.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
        }
        .padding(.horizontal, isExpanded ? 12 : 0)
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

private struct OpenRouterModelPicker: View {
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
