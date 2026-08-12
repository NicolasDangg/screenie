import AppKit
import CoreVideo
import ScreenCaptureKit

enum ScreenContextCapture {
    static func capture() async throws -> ScreenContext {
        guard CGPreflightScreenCaptureAccess() else {
            throw CGRequestScreenCaptureAccess()
                ? ScreenCaptureError.restartRequired
                : ScreenCaptureError.permissionDenied
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let displayID = displayUnderPointerID(),
              let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first
        else { throw ScreenCaptureError.noDisplay }

        let ownApplications = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        let scale = min(1, 2_400 / Double(display.width))
        configuration.width = Int(Double(display.width) * scale)
        configuration.height = Int(Double(display.height) * scale)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.capturesAudio = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        guard let jpeg = NSBitmapImageRep(cgImage: image).representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.78]
        ) else { throw ScreenCaptureError.encodingFailed }

        return try ScreenContext(imageData: jpeg, ocrText: VisionOCR.recognize(in: image))
    }

    private static func displayUnderPointerID() -> CGDirectDisplayID? {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        return screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case restartRequired
    case noDisplay
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Allow screen capture in System Settings, then try again."
        case .restartRequired: "Screen capture was enabled. Restart screenie, then try again."
        case .noDisplay: "No display is available to capture."
        case .encodingFailed: "The screenshot could not be encoded."
        }
    }
}
