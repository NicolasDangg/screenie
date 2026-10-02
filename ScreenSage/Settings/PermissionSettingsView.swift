import AppKit
import SwiftUI

struct PermissionSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var grantedPermissions = Set<AppPermission>()

    var body: some View {
        Section {
            ForEach(AppPermission.allCases) { permission in
                let isGranted = grantedPermissions.contains(permission)
                HStack(spacing: 10) {
                    statusDot(isGranted: isGranted, isRequired: permission.requirement == "Required")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(permission.title)
                        Text(permission.requirement)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isGranted {
                        Text("Allowed")
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Allow…") { request(permission) }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(isGranted ? "Allowed" : "Not allowed")
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("After allowing Screen Recording, restart screenie. If it isn’t listed, use Add in System Settings and choose /Applications/screenie.app.")
        }
        .task(refresh)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    /// Filled green when allowed; an orange ring when a required permission is missing, grey when optional.
    private func statusDot(isGranted: Bool, isRequired: Bool) -> some View {
        Group {
            if isGranted {
                Circle().fill(.green)
            } else {
                Circle().strokeBorder(isRequired ? .orange : .secondary, lineWidth: 1.5)
            }
        }
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }

    private func refresh() {
        grantedPermissions = Set(AppPermission.allCases.filter(\.isGranted))
    }

    private func request(_ permission: AppPermission) {
        let granted = permission.request()
        refresh()
        if !granted { NSWorkspace.shared.open(permission.settingsURL) }
    }
}
