import SwiftUI

struct OverlayAnswerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let messages: [ChatMessage]
    let streamingResponse: String
    let errorMessage: String
    let isWorking: Bool
    let includesScreenContext: Bool

    static func loadingLabel(includesScreenContext: Bool) -> String {
        includesScreenContext ? "Reading screen…" : "Thinking..."
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    Group {
                        if message.role == .assistant {
                            AssistantResponseText(text: message.text)
                        } else {
                            renderedText(message.text)
                        }
                    }
                        .textSelection(.enabled)
                        .padding(.horizontal, message.role == .user ? 10 : 0)
                        .padding(.vertical, message.role == .user ? 7 : 0)
                        .background(
                            message.role == .user ? Color.white.opacity(0.09) : .clear,
                            in: .rect(cornerRadius: 12)
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: message.role == .user ? .trailing : .leading
                        )
                }

                if !streamingResponse.isEmpty {
                    Text(streamingResponse)
                        .font(.system(size: 17))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                } else if isWorking {
                    let label = Self.loadingLabel(includesScreenContext: includesScreenContext)
                    if includesScreenContext {
                        ProgressView(label)
                            .controlSize(.small)
                    } else {
                        ThinkingIndicator(label: label)
                    }
                }

                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
            .padding(14)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: streamingResponse.isEmpty)
        }
        .defaultScrollAnchor(.bottom)
        .scrollIndicators(.hidden)
    }

    private func renderedText(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return Text((try? AttributedString(markdown: text, options: options)) ?? AttributedString(text))
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
