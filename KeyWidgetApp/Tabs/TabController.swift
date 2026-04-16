import AppKit
import KeyWidgetShared

final class TabController {
    private let store = SharedStore()

    func openFile(at url: URL) -> TabRef? {
        let absolute = url.resolvingSymlinksInPath().standardizedFileURL
        var state = store.load()

        if let existing = state.tabs.first(where: { tab in
            if let data = tab.bookmark,
               let resolved = resolveBookmark(data) {
                return resolved.resolvingSymlinksInPath().standardizedFileURL == absolute
            }
            return false
        }) {
            state.activeTabID = existing.id
            try? store.save(state)
            return existing
        }

        guard let bookmark = createBookmark(for: url) else { return nil }

        let title = (try? String(contentsOf: url, encoding: .utf8)).flatMap { md -> String? in
            let (t, _) = MarkdownPreview.extract(from: md)
            return t.isEmpty ? nil : t
        } ?? url.deletingPathExtension().lastPathComponent

        let new = TabRef(kind: .userFile, bookmark: bookmark, displayTitle: title)
        state.tabs.append(new)
        state.activeTabID = new.id
        try? store.save(state)
        return new
    }

    func createBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale { return nil }
        return url
    }

    func readContents(of tab: TabRef) -> String? {
        guard let data = tab.bookmark, let url = resolveBookmark(data) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
