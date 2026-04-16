import SwiftUI
import KeyWidgetShared

struct PreferencesView: View {
    @State private var state: Store = SharedStore().load()
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
            }
        }
        .padding(20)
        .frame(width: 420, height: 280)
    }

    private func save(postFloat: Bool = false, postTabs: Bool = false) {
        try? store.save(state)
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
        if postFloat { NotificationCenter.default.post(name: .floatDidChange, object: nil) }
        if postTabs { NotificationCenter.default.post(name: .tabsDidChange, object: nil) }
    }
}
