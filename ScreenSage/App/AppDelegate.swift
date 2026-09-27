import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationWasRequestedByUser = false

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
