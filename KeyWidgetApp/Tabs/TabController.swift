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

    func closeTab(id: UUID) {
        var state = store.load()
        guard let idx = state.tabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = state.activeTabID == id
        state.tabs.remove(at: idx)
        if wasActive, let fallback = state.tabs.first {
            state.activeTabID = fallback.id
        }
        try? store.save(state)
    }

    func canClose(_ tab: TabRef) -> Bool {
        tab.kind != .bundled
    }

    func moveTab(id: UUID, toIndex targetIndex: Int) {
        var state = store.load()
        guard let fromIndex = state.tabs.firstIndex(where: { $0.id == id }) else { return }
        let moved = state.tabs.remove(at: fromIndex)
        // Bundled tab must stay at index 0; clamp target accordingly
        let bundledAtZero = state.tabs.first?.kind == .bundled
        let clampedLow = bundledAtZero ? 1 : 0
        let clampedHigh = state.tabs.count
        let clamped = max(clampedLow, min(clampedHigh, targetIndex > fromIndex ? targetIndex - 1 : targetIndex))
        if moved.kind == .bundled {
            state.tabs.insert(moved, at: 0)
        } else {
            state.tabs.insert(moved, at: clamped)
        }
        try? store.save(state)
    }
}
