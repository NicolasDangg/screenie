import AppKit
import SwiftUI

struct OverlayAnswerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let messages: [ChatMessage]
    let streamingResponse: String
    let errorMessage: String
    let workPhase: WorkPhase?
    /// The screenshot sent with the latest prompt; shown above that prompt and never saved.
    let attachedScreenshot: Data?
    let askAgain: () -> Void

    @State private var copiedMessageID: ChatMessage.ID?

    static func progressSteps(for phase: WorkPhase?) -> [(title: String, state: ProgressStepState)] {
        switch phase {
        case .capturing:
            [("Capturing", .active), ("Reading text", .pending)]
        case .readingText:
            [("Captured", .done), ("Reading text", .active)]
        case .thinking, nil:
            []
        }
    }

    private var lastUserMessageID: ChatMessage.ID? {
        messages.last { $0.role == .user }?.id
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(messages) { message in
                    if message.role == .assistant {
                        VStack(alignment: .leading, spacing: 6) {
                            AssistantResponseText(text: message.text)
                                .textSelection(.enabled)
                            if message.id == messages.last?.id, workPhase == nil {
                                answerActions(for: message)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        userMessage(message)
                    }
                }

                if !streamingResponse.isEmpty {
                    StreamingResponseText(text: streamingResponse)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                } else if let workPhase {
                    if workPhase == .thinking {
                        ThinkingIndicator(label: "Thinking…")
                    } else {
                        ProgressSteps(steps: Self.progressSteps(for: workPhase))
                    }
                }

                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
            .padding(.horizontal, OverlayLayout.contentInset)
            .padding(.vertical, 14)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: streamingResponse.isEmpty)
        }
        .defaultScrollAnchor(.bottom)
        .scrollIndicators(.hidden)
    }

    private func userMessage(_ message: ChatMessage) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            if message.id == lastUserMessageID,
               let attachedScreenshot,
               let image = NSImage(data: attachedScreenshot) {
                HStack(spacing: 6) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 34, height: 20)
                        .clipShape(.rect(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.2)))
                    Text("Screen attached")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Screenshot sent with this message")
                .transition(reduceMotion ? .identity : .opacity)
            }
            renderedText(message.text)
                .font(.system(size: 14))
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    .primary.opacity(0.09),
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 14,
                        bottomLeadingRadius: 14,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 14
                    )
                )
        }
        .padding(.leading, 60)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func answerActions(for message: ChatMessage) -> some View {
        HStack(spacing: 2) {
            actionButton(
                copiedMessageID == message.id ? "Copied" : "Copy answer",
                systemImage: copiedMessageID == message.id ? "checkmark" : "doc.on.doc"
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.text, forType: .string)
                copiedMessageID = message.id
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    if copiedMessageID == message.id { copiedMessageID = nil }
                }
            }
            actionButton("Ask again with a new screenshot", systemImage: "arrow.clockwise", action: askAgain)
        }
        .padding(.leading, -6)
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(width: 26, height: 26)
            .contentShape(.rect)
            .help(title)
    }

    private func renderedText(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return Text((try? AttributedString(markdown: text, options: options)) ?? AttributedString(text))
    }
}

enum ProgressStepState: Equatable {
    case pending
    case active
    case done
}

/// "✓ Captured — Reading text" while a screenshot is being captured and read.
private struct ProgressSteps: View {
    let steps: [(title: String, state: ProgressStepState)]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Rectangle()
                        .fill(.primary.opacity(0.18))
                        .frame(width: 18, height: 1)
                }
                HStack(spacing: 6) {
                    switch step.state {
                    case .done:
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.tint)
                    case .active:
                        ProgressView().controlSize(.mini)
                    case .pending:
                        EmptyView()
                    }
                    Text(step.title)
                        .fontWeight(step.state == .active ? .semibold : .regular)
                        .foregroundStyle(step.state == .active ? AnyShapeStyle(.primary)
                                         : step.state == .done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                }
            }
        }
        .font(.system(size: 12.5))
        .accessibilityElement(children: .combine)
    }
}

private struct ThinkingIndicator: View {
    let label: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Text(label)
                    .foregroundStyle(.secondary)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 1.4) / 1.4
                    let start = CGFloat(phase * 2 - 1)

                    Text(label)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.secondary, .primary, .secondary],
                                startPoint: UnitPoint(x: start, y: 0.5),
                                endPoint: UnitPoint(x: start + 1, y: 0.5)
                            )
                        )
                }
            }
        }
        .font(.callout.weight(.medium))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thinking")
    }
}
