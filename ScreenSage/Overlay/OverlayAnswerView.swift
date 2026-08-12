import SwiftUI

struct OverlayAnswerView: View {
    let answer: String
    let errorMessage: String
    let isWorking: Bool
    let openScreenRecordingSettings: () -> Void

    var body: some View {
        Group {
            if !errorMessage.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    HStack {
                        SettingsLink { Text("Open Settings") }
                        Button("Screen Recording Settings", action: openScreenRecordingSettings)
                    }
                }
            } else if answer.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ask about what’s on your screen")
                        .font(.title3)
                        .bold()
                    Text("A single screenshot and local Vision OCR are attached only after you press Return.")
                        .foregroundStyle(.secondary)
                    if isWorking { ProgressView().controlSize(.small) }
                }
            } else {
                ScrollView {
                    Text(answer)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .glassEffect(.regular.tint(.white.opacity(0.04)), in: .rect(cornerRadius: 16))
    }
}
