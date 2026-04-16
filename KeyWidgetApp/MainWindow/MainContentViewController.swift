import AppKit
import KeyWidgetShared

final class MainContentViewController: NSViewController {
    private let store = SharedStore()
    private var state: Store = .defaultStore

    private let tabBar = TabBarView()
    private let markdownView = MarkdownWebView()
    private let divider = NSBox()

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
        reload()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: .tabsDidChange, object: nil
        )
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
    }

    private func loadActiveTabContent() {
        guard let tab = state.tabs.first(where: { $0.id == state.activeTabID }) else { return }
        switch tab.kind {
        case .bundled:
            if let url = Bundle.main.url(forResource: "cheatsheet", withExtension: "md"),
               let md = try? String(contentsOf: url, encoding: .utf8) {
                markdownView.loadMarkdown(md, theme: state.theme)
            }
        case .userFile:
            let controller = (NSApp.delegate as? AppDelegate)?.tabController
            if let md = controller.flatMap({ $0.readContents(of: tab) }) {
                markdownView.loadMarkdown(md, theme: state.theme)
            } else {
                markdownView.loadMarkdown("# Couldn't find this file", theme: state.theme)
            }
        }
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
