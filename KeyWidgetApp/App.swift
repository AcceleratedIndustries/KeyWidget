import SwiftUI

@main
struct KeyWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { PreferencesView() }
    }
}
