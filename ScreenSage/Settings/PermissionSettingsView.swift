import AppKit
import SwiftUI

struct PermissionSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var grantedPermissions = Set<AppPermission>()

    var body: some View {
        Section("Permissions") {
            ForEach(AppPermission.allCases) { permission in
                HStack {
                    VStack(alignment: .leading) {
                        Text(permission.title)
                        Text(permission.requirement)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(
                        grantedPermissions.contains(permission) ? "Enabled" : "Disabled",
                        systemImage: grantedPermissions.contains(permission) ? "checkmark.circle.fill" : "xmark.circle"
                    )
                    .foregroundStyle(grantedPermissions.contains(permission) ? .green : .secondary)
                    Button("Open Settings") { openSettings(for: permission) }
                }
            }
        }
        .task(refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private func refresh() {
        grantedPermissions = Set(AppPermission.allCases.filter(\.isGranted))
    }

    private func openSettings(for permission: AppPermission) {
        NSWorkspace.shared.open(permission.settingsURL)
    }
}
