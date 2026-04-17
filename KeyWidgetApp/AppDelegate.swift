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

        let toolbar = NSToolbar(identifier: "main")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        applyFloatOnTop()
        NotificationCenter.default.addObserver(
            self, selector: #selector(floatChanged),
            name: .floatDidChange, object: nil
        )
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
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(AppDelegate.showPreferences(_:)), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(prefsItem)
        appMenu.addItem(.separator())
        let hideItem = NSMenuItem(title: "Hide KeyWidget", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(hideItem)
        let quitItem = NSMenuItem(title: "Quit KeyWidget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)
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

        // View menu
        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let floatItem = NSMenuItem(title: "Float on Top", action: #selector(AppDelegate.toggleFloat), keyEquivalent: "f")
        floatItem.keyEquivalentModifierMask = [.control, .option, .command]
        viewMenu.addItem(floatItem)
        let themeSubmenu = NSMenu(title: "Theme")
        for theme in Theme.allCases {
            let mi = NSMenuItem(title: theme.displayName, action: #selector(AppDelegate.selectTheme(_:)), keyEquivalent: "")
            mi.representedObject = theme.rawValue
            themeSubmenu.addItem(mi)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeSubmenu
        viewMenu.addItem(themeItem)
        viewMenu.addItem(.separator())
        let zoomIn = NSMenuItem(title: "Zoom In", action: #selector(AppDelegate.zoomIn(_:)), keyEquivalent: "+")
        zoomIn.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomIn)
        let zoomOut = NSMenuItem(title: "Zoom Out", action: #selector(AppDelegate.zoomOut(_:)), keyEquivalent: "-")
        zoomOut.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomOut)
        let zoomReset = NSMenuItem(title: "Actual Size", action: #selector(AppDelegate.zoomReset(_:)), keyEquivalent: "0")
        zoomReset.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomReset)
        viewItem.submenu = viewMenu
        main.addItem(viewItem)

        return main
    }

    @objc func zoomIn(_ sender: Any?)    { NotificationCenter.default.post(name: .zoomRequested, object: "in") }
    @objc func zoomOut(_ sender: Any?)   { NotificationCenter.default.post(name: .zoomRequested, object: "out") }
    @objc func zoomReset(_ sender: Any?) { NotificationCenter.default.post(name: .zoomRequested, object: "reset") }

    @objc func selectTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let theme = Theme(rawValue: raw) else { return }
        let store = SharedStore()
        var s = store.load()
        s.theme = theme
        try? store.save(s)
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }

    @objc func toggleFloat() {
        var s = SharedStore().load()
        s.floatOnTop = !s.floatOnTop
        try? SharedStore().save(s)
        applyFloatOnTop()
        NotificationCenter.default.post(name: .floatDidChange, object: nil)
    }

    func applyFloatOnTop() {
        let s = SharedStore().load()
        mainWindow?.level = s.floatOnTop ? .floating : .normal
        updatePinButtonImage(isPinned: s.floatOnTop)
    }

    private func updatePinButtonImage(isPinned: Bool) {
        let symbol = isPinned ? "pin.fill" : "pin"
        if let toolbar = mainWindow?.toolbar,
           let item = toolbar.items.first(where: { $0.itemIdentifier == Self.floatItemID }),
           let button = item.view as? NSButton {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
    }

    @objc func floatChanged() { applyFloatOnTop() }
}

extension AppDelegate: NSToolbarDelegate {
    static let floatItemID = NSToolbarItem.Identifier("floatOnTop")

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.floatItemID, .flexibleSpace]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.floatItemID]
    }
    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier == Self.floatItemID else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Float on Top"
        let button = NSButton(image: NSImage(systemSymbolName: "pin", accessibilityDescription: "Float on Top")!, target: self, action: #selector(toggleFloat))
        button.isBordered = false
        item.view = button
        return item
    }
}
