import WidgetKit
import KeyWidgetShared

struct KeyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeyWidgetEntry {
        KeyWidgetEntry(
            date: .now,
            title: "macOS Keybindings",
            preview: "Spotlight search\n⌘ Space\nLock screen\n⌃ ⌘ Q",
            theme: .iaWriter,
            tabID: TabRef.bundledID,
            isMissing: false,
            isFirstLaunch: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KeyWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeyWidgetEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }

    private func makeEntry() -> KeyWidgetEntry {
        let store = SharedStore().load()
        let tab = store.tabs.first { $0.id == store.activeTabID } ?? TabRef.bundled
        let isFirstLaunch = (store == .defaultStore && store.tabs.count == 1 && store.tabs[0].kind == .bundled)

        var title = tab.displayTitle
        var preview = ""
        var isMissing = false

        switch tab.kind {
        case .bundled:
            if let url = Bundle.main.url(forResource: "cheatsheet", withExtension: "md"),
               let md = try? String(contentsOf: url, encoding: .utf8) {
                let (t, p) = MarkdownPreview.extract(from: md, maxLines: 10)
                if !t.isEmpty { title = t }
                preview = p
            }
        case .userFile:
            if let md = readUserFile(tab: tab) {
                let (t, p) = MarkdownPreview.extract(from: md, maxLines: 10)
                if !t.isEmpty { title = t }
                preview = p
            } else {
                isMissing = true
            }
        }

        return KeyWidgetEntry(
            date: .now,
            title: title,
            preview: preview,
            theme: store.theme,
            tabID: tab.id,
            isMissing: isMissing,
            isFirstLaunch: isFirstLaunch
        )
    }

    private func readUserFile(tab: TabRef) -> String? {
        guard let data = tab.bookmark else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
