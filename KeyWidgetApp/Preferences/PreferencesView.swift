import SwiftUI
import ServiceManagement
import KeyWidgetShared

struct PreferencesView: View {
    @State private var state: Store = SharedStore().load()
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    private let store = SharedStore()

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $state.theme) {
                    ForEach(Theme.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: state.theme) { _, _ in save() }
            }

            Section("Behavior") {
                Toggle("Float on top", isOn: $state.floatOnTop)
                    .onChange(of: state.floatOnTop) { _, _ in save(postFloat: true) }
                Toggle("Hide the bundled cheat sheet tab", isOn: $state.hideDefaultDoc)
                    .onChange(of: state.hideDefaultDoc) { _, _ in save(postTabs: true) }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }
        }
        .padding(20)
        .frame(width: 420, height: 320)
    }

    private func save(postFloat: Bool = false, postTabs: Bool = false) {
        try? store.save(state)
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
        if postFloat { NotificationCenter.default.post(name: .floatDidChange, object: nil) }
        if postTabs { NotificationCenter.default.post(name: .tabsDidChange, object: nil) }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert UI if the system refused (e.g. user denied in System Settings)
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
