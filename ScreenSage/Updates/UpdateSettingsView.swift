import AppKit
import SwiftUI

struct UpdateSettingsView: View {
    @Bindable var updater: AppUpdater

    var body: some View {
        Section("Updates") {
            LabeledContent("Current version", value: updater.currentVersion)
            switch updater.state {
            case .idle:
                checkButton
            case .checking:
                LabeledContent("Checking for updates…") { ProgressView().controlSize(.small) }
            case .upToDate:
                HStack {
                    Label("screenie is up to date", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Spacer()
                    checkButton
                }
            case .available(let release):
                HStack {
                    Text("Version \(release.version) is available")
                    Spacer()
                    Button("Release Notes") { NSWorkspace.shared.open(release.pageURL) }
                    Button("Download and Install") { Task { await updater.install(release) } }
                        .buttonStyle(.borderedProminent)
                }
            case .installing:
                LabeledContent("Downloading and installing…") { ProgressView().controlSize(.small) }
            case .failed(let message):
                HStack {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    checkButton
                }
            }
        }
    }

    private var checkButton: some View {
        Button("Check for Updates") { Task { await updater.checkForUpdates() } }
    }
}
