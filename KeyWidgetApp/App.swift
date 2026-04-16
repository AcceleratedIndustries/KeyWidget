import SwiftUI

@main
struct KeyWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Preferences placeholder")
                .frame(width: 420, height: 300)
        }
    }
}
