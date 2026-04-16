import AppKit
import KeyWidgetShared

@MainActor
enum DeepLinkHandler {
    static func handle(_ url: URL) {
        guard let link = DeepLink.parse(url) else { return }
        switch link {
        case .openApp:
            NSApp.activate(ignoringOtherApps: true)
            (NSApp.delegate as? AppDelegate)?.mainWindow?.makeKeyAndOrderFront(nil)
        case .openTab(let id):
            NSApp.activate(ignoringOtherApps: true)
            (NSApp.delegate as? AppDelegate)?.mainWindow?.makeKeyAndOrderFront(nil)
            var state = SharedStore().load()
            if state.tabs.contains(where: { $0.id == id }) {
                state.activeTabID = id
                try? SharedStore().save(state)
                NotificationCenter.default.post(name: .tabsDidChange, object: nil)
            }
        }
    }
}
