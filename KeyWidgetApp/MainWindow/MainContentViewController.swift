import AppKit
import KeyWidgetShared

final class MainContentViewController: NSViewController {
    private let store = SharedStore()
    private var state: Store = .defaultStore

    private let tabBar = TabBarView()
    private let markdownView = MarkdownWebView()
    private let divider = NSBox()

    override func loadView() {
        let container = NSView()
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

        tabBar.onSelect = { [weak self] id in self?.selectTab(id) }
        reload()
    }

    private func reload() {
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
            // Will be implemented in Task 13 (security-scoped bookmark resolution)
            markdownView.loadMarkdown("Loading not yet implemented for user files.", theme: state.theme)
        }
    }
}
