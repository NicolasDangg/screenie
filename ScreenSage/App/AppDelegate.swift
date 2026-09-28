import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// SwiftUI's delegate adaptor wraps this object, so `NSApp.delegate` isn't castable to it.
    private(set) static weak var shared: AppDelegate?
    private var terminationWasRequestedByUser = false

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard NSClassFromString("XCTestCase") == nil else { return }
        AppRuntime.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        terminationWasRequestedByUser ? .terminateNow : .terminateCancel
    }

    func requestTermination() {
        terminationWasRequestedByUser = true
        NSApp.terminate(nil)
    }
}
