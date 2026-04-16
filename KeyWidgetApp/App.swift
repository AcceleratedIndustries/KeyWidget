import SwiftUI

@main
struct KeyWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { PreferencesView() }
    }

    init() {
        NSAppleEventManager.shared().setEventHandler(
            AppURLHandler.shared,
            andSelector: #selector(AppURLHandler.handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
}

@MainActor
final class AppURLHandler: NSObject {
    static let shared = AppURLHandler()
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        DeepLinkHandler.handle(url)
    }
}
