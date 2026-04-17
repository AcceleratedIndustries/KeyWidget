import AppKit
import KeyWidgetShared
import os

@MainActor
enum DeepLinkHandler {
    private static let log = Logger(subsystem: "com.williamappleton.keywidget", category: "DeepLink")

    static func handle(_ url: URL) {
        log.info("handle \(url.absoluteString, privacy: .public)")
        guard let link = DeepLink.parse(url) else {
            log.error("could not parse URL")
            return
        }
        let bringWindowForward: () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
            if let window = (NSApp.delegate as? AppDelegate)?.mainWindow {
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
            }
        }
        switch link {
        case .openApp:
            bringWindowForward()
        case .openTab(let id):
            bringWindowForward()
            var state = SharedStore().load()
            if state.tabs.contains(where: { $0.id == id }) {
                state.activeTabID = id
                try? SharedStore().save(state)
                NotificationCenter.default.post(name: .tabsDidChange, object: nil)
            }
        }
    }
}
