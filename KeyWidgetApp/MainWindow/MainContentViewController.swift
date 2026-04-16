import AppKit
import KeyWidgetShared
import UniformTypeIdentifiers

@MainActor
final class MainContentViewController: NSViewController {
    private let store = SharedStore()
    private var state: Store = .defaultStore

    private let tabBar = TabBarView()
    private let markdownView = MarkdownWebView()
    private let divider = NSBox()
    private var watcher: FileWatcher?
    private var missingVC: MissingFileViewController?

    override func loadView() {
        let container = DropView()
        view = container

        divider.boxType = .separator
        [tabBar, divider, markdownView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: container.topAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 32),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            markdownView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            markdownView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            markdownView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            markdownView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        container.registerForDraggedTypes([.fileURL])
        container.onDrop = { [weak self] urls in
            guard let self else { return }
            let controller = (NSApp.delegate as? AppDelegate)?.tabController
            for url in urls { _ = controller?.openFile(at: url) }
            self.reload()
        }

        tabBar.onSelect = { [weak self] id in self?.selectTab(id) }
        tabBar.onClose = { [weak self] id in self?.closeTab(id: id) }
        tabBar.onReorder = { [weak self] id, idx in
            (NSApp.delegate as? AppDelegate)?.tabController.moveTab(id: id, toIndex: idx)
            self?.reload()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(closeActiveTab),
            name: .closeActiveTabRequested, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(themeChanged),
            name: .themeDidChange, object: nil
        )
        reload()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: .tabsDidChange, object: nil
        )
    }

    @objc private func themeChanged() {
        state = store.load()
        markdownView.apply(theme: state.theme)
        WidgetReloader.reload()
    }

    private func closeTab(id: UUID) {
        let controller = (NSApp.delegate as? AppDelegate)?.tabController
        guard let tab = state.tabs.first(where: { $0.id == id }),
              controller?.canClose(tab) == true else { return }
        controller?.closeTab(id: id)
        reload()
    }

    @objc private func closeActiveTab() {
        closeTab(id: state.activeTabID)
    }

    @objc private func reload() {
        state = store.load()
        tabBar.setTabs(visibleTabs(), activeID: state.activeTabID)
        loadActiveTabContent()
        WidgetReloader.reload()
    }

    private func visibleTabs() -> [TabRef] {
        state.hideDefaultDoc
            ? state.tabs.filter { $0.kind != .bundled }
            : state.tabs
    }

    private func selectTab(_ id: UUID) {
        state.activeTabID = id
        try? store.save(state)
        tabBar.updateActive(id)
        loadActiveTabContent()
        WidgetReloader.reload()
    }

    private func loadActiveTabContent() {
        guard let tab = state.tabs.first(where: { $0.id == state.activeTabID }) else { return }
        switch tab.kind {
        case .bundled:
            if let url = Bundle.main.url(forResource: "cheatsheet", withExtension: "md"),
               let md = try? String(contentsOf: url, encoding: .utf8) {
                showMarkdown(md, baseURL: nil)
            }
        case .userFile:
            let controller = (NSApp.delegate as? AppDelegate)?.tabController
            guard let bookmark = tab.bookmark, let url = controller?.resolveBookmark(bookmark) else {
                showMissing(path: "", tab: tab)
                return
            }
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            if let md = try? String(contentsOf: url, encoding: .utf8) {
                showMarkdown(md, baseURL: url.deletingLastPathComponent())
                refreshTabTitle(from: md, tabID: tab.id)
                WidgetReloader.reload()
                startWatching(url)
            } else {
                showMissing(path: url.path, tab: tab)
            }
        }
    }

    private func showMarkdown(_ md: String, baseURL: URL?) {
        missingVC?.view.removeFromSuperview()
        missingVC?.removeFromParent()
        missingVC = nil
        if markdownView.superview == nil { addMarkdownView() }
        markdownView.loadMarkdown(md, theme: state.theme, baseURL: baseURL)
    }

    private func showMissing(path: String, tab: TabRef) {
        markdownView.removeFromSuperview()
        missingVC?.view.removeFromSuperview()
        missingVC?.removeFromParent()
        let vc = MissingFileViewController()
        vc.pathHint = path
        vc.onLocate = { [weak self] in self?.relink(tab: tab) }
        vc.onRemove = { [weak self] in self?.closeTab(id: tab.id) }
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vc.view.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        missingVC = vc
    }

    private func addMarkdownView() {
        view.addSubview(markdownView)
        markdownView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            markdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            markdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            markdownView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            markdownView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func relink(tab: TabRef) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md")!]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let controller = (NSApp.delegate as? AppDelegate)?.tabController,
                  let bookmark = controller.createBookmark(for: url) else { return }
            var state = self?.store.load() ?? .defaultStore
            if let idx = state.tabs.firstIndex(where: { $0.id == tab.id }) {
                state.tabs[idx].bookmark = bookmark
                try? self?.store.save(state)
            }
            self?.reload()
        }
    }

    private func startWatching(_ url: URL) {
        watcher?.stop()
        watcher = FileWatcher(url: url) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self?.loadActiveTabContent()
            }
        }
        watcher?.start()
    }

    private func refreshTabTitle(from markdown: String, tabID: UUID) {
        let (title, _) = MarkdownPreview.extract(from: markdown)
        guard !title.isEmpty else { return }
        var s = store.load()
        guard let idx = s.tabs.firstIndex(where: { $0.id == tabID }),
              s.tabs[idx].displayTitle != title else { return }
        s.tabs[idx].displayTitle = title
        try? store.save(s)
        state = s
        tabBar.setTabs(visibleTabs(), activeID: state.activeTabID)
    }
}

private final class DropView: NSView {
    var onDrop: (([URL]) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil) ? .copy : []
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        let mdURLs = urls.filter { ["md","markdown","mdown","mdx"].contains($0.pathExtension.lowercased()) }
        guard !mdURLs.isEmpty else { return false }
        onDrop?(mdURLs)
        return true
    }
}
