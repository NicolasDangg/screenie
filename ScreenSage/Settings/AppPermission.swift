@preconcurrency import ApplicationServices
import CoreGraphics
import Foundation

enum AppPermission: CaseIterable, Identifiable {
    case screenRecording
    case accessibility
    case inputMonitoring

    var id: Self { self }

    var title: String {
        switch self {
        case .screenRecording: "Screen Recording"
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        }
    }

    var requirement: String {
        self == .screenRecording ? "Required" : "Optional"
    }

    var settingsURL: URL {
        let anchor = switch self {
        case .screenRecording: "Privacy_ScreenCapture"
        case .accessibility: "Privacy_Accessibility"
        case .inputMonitoring: "Privacy_ListenEvent"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
    }

    var isGranted: Bool {
        switch self {
        case .screenRecording: CGPreflightScreenCaptureAccess()
        case .accessibility: AXIsProcessTrusted()
        case .inputMonitoring: CGPreflightListenEventAccess()
        }
    }

    @discardableResult
    func request() -> Bool {
        switch self {
        case .screenRecording:
            CGRequestScreenCaptureAccess()
        case .accessibility:
            AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary)
        case .inputMonitoring:
            CGRequestListenEventAccess()
        }
    }
}
