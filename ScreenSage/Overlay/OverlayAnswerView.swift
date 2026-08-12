import SwiftUI

struct OverlayAnswerView: View {
    let messages: [ChatMessage]
    let streamingResponse: String
    let errorMessage: String
    let isWorking: Bool

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(messages) { message in
                    Text(message.text)
                        .textSelection(.enabled)
                        .frame(
                            maxWidth: .infinity,
                            alignment: message.role == .user ? .trailing : .leading
                        )
                        .padding(.horizontal, message.role == .user ? 10 : 0)
                        .padding(.vertical, message.role == .user ? 7 : 0)
                        .background(
                            message.role == .user ? Color.white.opacity(0.09) : .clear,
                            in: .rect(cornerRadius: 12)
                        )
                }

                if !streamingResponse.isEmpty {
                    Text(streamingResponse)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if isWorking {
                    ProgressView("Reading screen…")
                        .controlSize(.small)
                }

                if !errorMessage.isEmpty {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }
            .padding(14)
        }
        .defaultScrollAnchor(.bottom)
        .scrollIndicators(.hidden)
    }
}
