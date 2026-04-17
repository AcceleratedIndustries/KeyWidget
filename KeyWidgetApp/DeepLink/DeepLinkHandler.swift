import AppKit
import KeyWidgetShared
import os

@MainActor
enum DeepLinkHandler {
    private static let log = Logger(subsystem: "com.williamappleton.keywidget", category: "DeepLink")

    static func handle(_ url: URL) {
        guard let link = DeepLink.parse(url) else {
            log.error("could not parse URL")
            return
        }
        let bringWindowForward: () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
            if let window = AppDelegate.shared?.mainWindow {
                if window.isMiniaturized { window.deminiaturize(nil) }
                window.makeKeyAndOrderFront(nil)
                // In newer macOS the foreground activation sometimes drops on the floor unless
                // dispatched again after a run-loop tick.
                DispatchQueue.main.async {
                    NSApp.activate(ignoringOtherApps: true)
                    window.orderFrontRegardless()
                }
            } else {
                log.error("no mainWindow")
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
