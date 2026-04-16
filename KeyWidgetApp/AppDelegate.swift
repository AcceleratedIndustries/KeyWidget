import AppKit
import KeyWidgetShared

final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vc = MainContentViewController()
        let window = NSWindow(contentViewController: vc)
        window.setContentSize(NSSize(width: 720, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.title = "KeyWidget"
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindow?.makeKeyAndOrderFront(nil) }
        return true
    }
}
