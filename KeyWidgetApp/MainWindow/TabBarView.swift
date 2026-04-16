import AppKit
import KeyWidgetShared

final class TabBarView: NSView {
    var onSelect: ((UUID) -> Void)?
    var onClose: ((UUID) -> Void)?
    var onReorder: ((UUID, Int) -> Void)?

    func reorderDidEnd(draggedTabID: UUID, toPointInSelf point: NSPoint) {
        // point may be in this view's bounds or inside the scroll view's stack.
        // Project all item mid-X coords into this view's coordinate system.
        let xs = itemViews.map { item -> CGFloat in
            let f = item.convert(item.bounds, to: self)
            return f.midX
        }
        let targetIndex = xs.firstIndex(where: { point.x < $0 }) ?? itemViews.count
        onReorder?(draggedTabID, targetIndex)
    }

    private let scrollView = NSScrollView()
    private let stack = NSStackView()
    private var itemViews: [TabBarItemView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: -1, height: 32) }

    func setTabs(_ tabs: [TabRef], activeID: UUID) {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews = tabs.map { tab in
            let item = TabBarItemView(tab: tab)
            item.setActive(tab.id == activeID)
            item.onClick = { [weak self] in self?.onSelect?(tab.id) }
            item.onClose = { [weak self] in
                guard let self, tab.kind != .bundled else { return }
                self.onClose?(tab.id)
            }
            return item
        }
        itemViews.forEach { stack.addArrangedSubview($0) }
    }

    func updateActive(_ activeID: UUID) {
        itemViews.forEach { $0.setActive($0.tab.id == activeID) }
    }
}
