import AppKit
import KeyWidgetShared

final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?
    var markdownView: MarkdownWebView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyWidget"
        window.center()

        let view = MarkdownWebView(frame: .zero)
        window.contentView = view
        self.markdownView = view

        loadBundledCheatsheet()

        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindow?.makeKeyAndOrderFront(nil) }
        return true
    }

    private func loadBundledCheatsheet() {
        guard let url = Bundle.main.url(forResource: "cheatsheet", withExtension: "md"),
              let md = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        markdownView?.loadMarkdown(md, theme: .iaWriter)
    }
}
