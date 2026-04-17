import AppKit
import KeyWidgetShared
import os
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?
    let tabController = TabController()
    private let log = Logger(subsystem: "com.williamappleton.keywidget", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("applicationDidFinishLaunching self=\(ObjectIdentifier(self).hashValue, privacy: .public)")
        NSApp.mainMenu = buildMenu()

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

    // Delivered when the app is already running and macOS routes a keywidget:// URL to it.
    func application(_ application: NSApplication, open urls: [URL]) {
        log.info("application(open:) self=\(ObjectIdentifier(self).hashValue, privacy: .public) mainWindow=\(self.mainWindow != nil ? "set" : "nil", privacy: .public)")
        for url in urls { handleDeepLink(url) }
    }

    private func handleDeepLink(_ url: URL) {
        guard let link = DeepLink.parse(url) else { return }
        bringMainWindowForward()
        if case let .openTab(id) = link {
            var state = SharedStore().load()
            if state.tabs.contains(where: { $0.id == id }) {
                state.activeTabID = id
                try? SharedStore().save(state)
                NotificationCenter.default.post(name: .tabsDidChange, object: nil)
            }
        }
    }

    private func bringMainWindowForward() {
        NSApp.activate(ignoringOtherApps: true)
        guard let window = mainWindow else {
            log.error("bringMainWindowForward: mainWindow is nil")
            return
        }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
        }
    }

    @objc func openFileMenu(_ sender: Any?) {
        log.info("openFileMenu invoked")
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!,
            UTType(filenameExtension: "mdown")!,
            UTType(filenameExtension: "mdx")!,
        ]
        panel.allowsMultipleSelection = true
        panel.begin { [weak self] response in
            self?.log.info("NSOpenPanel response=\(response.rawValue, privacy: .public) urls=\(panel.urls.map(\.path), privacy: .public)")
            guard response == .OK else { return }
            for url in panel.urls {
                let result = self?.tabController.openFile(at: url)
                self?.log.info("openFile \(url.path, privacy: .public) -> \(result?.id.uuidString ?? "nil", privacy: .public)")
            }
            NotificationCenter.default.post(name: .tabsDidChange, object: nil)
        }
    }

    @objc func closeTabMenu(_ sender: Any?) {
        NotificationCenter.default.post(name: .closeActiveTabRequested, object: nil)
    }

    private var preferencesWindow: NSWindow?

    @objc func showPreferences(_ sender: Any?) {
        log.info("showPreferences invoked")
        if let w = preferencesWindow {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: PreferencesView())
        let win = NSWindow(contentViewController: host)
        win.title = "Preferences"
        win.styleMask = [.titled, .closable]
        win.center()
        win.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        preferencesWindow = win
        log.info("created preferences window")
    }

    private func buildMenu() -> NSMenu {
        let main = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let prefsItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = [.command]
        prefsItem.target = self
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
        let openItem = NSMenuItem(title: "Open…", action: #selector(openFileMenu(_:)), keyEquivalent: "o")
        openItem.target = self
        fileMenu.addItem(openItem)
        let closeTab = NSMenuItem(title: "Close Tab", action: #selector(closeTabMenu(_:)), keyEquivalent: "w")
        closeTab.target = self
        fileMenu.addItem(closeTab)
        let closeWin = NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        closeWin.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(closeWin)
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        // View menu
        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        let floatItem = NSMenuItem(title: "Float on Top", action: #selector(toggleFloat), keyEquivalent: "f")
        floatItem.keyEquivalentModifierMask = [.control, .option, .command]
        floatItem.target = self
        viewMenu.addItem(floatItem)
        let themeSubmenu = NSMenu(title: "Theme")
        for theme in Theme.allCases {
            let mi = NSMenuItem(title: theme.displayName, action: #selector(selectTheme(_:)), keyEquivalent: "")
            mi.representedObject = theme.rawValue
            mi.target = self
            themeSubmenu.addItem(mi)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeSubmenu
        viewMenu.addItem(themeItem)
        viewMenu.addItem(.separator())
        // Accept ⌘= (same physical key as ⌘+ without shift) and ⌘+ for zoom-in.
        let zoomIn = NSMenuItem(title: "Zoom In", action: #selector(zoomIn(_:)), keyEquivalent: "=")
        zoomIn.keyEquivalentModifierMask = [.command]
        zoomIn.target = self
        viewMenu.addItem(zoomIn)
        let zoomInShift = NSMenuItem(title: "Zoom In", action: #selector(zoomIn(_:)), keyEquivalent: "+")
        zoomInShift.keyEquivalentModifierMask = [.command, .shift]
        zoomInShift.isAlternate = true
        zoomInShift.isHidden = true
        zoomInShift.target = self
        viewMenu.addItem(zoomInShift)
        let zoomOut = NSMenuItem(title: "Zoom Out", action: #selector(zoomOut(_:)), keyEquivalent: "-")
        zoomOut.keyEquivalentModifierMask = [.command]
        zoomOut.target = self
        viewMenu.addItem(zoomOut)
        let zoomReset = NSMenuItem(title: "Actual Size", action: #selector(zoomReset(_:)), keyEquivalent: "0")
        zoomReset.keyEquivalentModifierMask = [.command]
        zoomReset.target = self
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
