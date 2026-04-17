import AppKit
import KeyWidgetShared

@MainActor
enum DeepLinkHandler {
    static func handle(_ url: URL) {
        guard let link = DeepLink.parse(url) else { return }
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
