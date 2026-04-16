import AppKit
import KeyWidgetShared
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?
    let tabController = TabController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.buildMenu()

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

    @objc func openFileMenu(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!,
            UTType(filenameExtension: "mdown")!,
            UTType(filenameExtension: "mdx")!,
        ]
        panel.allowsMultipleSelection = true
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            for url in panel.urls {
                _ = self?.tabController.openFile(at: url)
            }
            NotificationCenter.default.post(name: .tabsDidChange, object: nil)
        }
    }

    @objc func closeTabMenu(_ sender: Any?) {
        NotificationCenter.default.post(name: .closeActiveTabRequested, object: nil)
    }

    @objc func showPreferences(_ sender: Any?) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private static func buildMenu() -> NSMenu {
        let main = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Preferences…", action: #selector(AppDelegate.showPreferences(_:)), keyEquivalent: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide KeyWidget", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Quit KeyWidget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        main.addItem(appMenuItem)

        // File menu
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Open…", action: #selector(AppDelegate.openFileMenu(_:)), keyEquivalent: "o"))
        let closeTab = NSMenuItem(title: "Close Tab", action: #selector(AppDelegate.closeTabMenu(_:)), keyEquivalent: "w")
        fileMenu.addItem(closeTab)
        let closeWin = NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        closeWin.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(closeWin)
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        return main
    }
}
