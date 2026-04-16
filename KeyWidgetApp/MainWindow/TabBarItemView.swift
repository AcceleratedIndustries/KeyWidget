import AppKit
import KeyWidgetShared

final class TabBarItemView: NSView {
    let tab: TabRef
    var isActive: Bool = false { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?
    var onClose: (() -> Void)?

    private let label = NSTextField(labelWithString: "")

    init(tab: TabRef) {
        self.tab = tab
        super.init(frame: .zero)
        label.stringValue = tab.displayTitle.isEmpty ? "Untitled" : tab.displayTitle
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isActive {
            let underline = NSRect(x: 10, y: 0, width: bounds.width - 20, height: 2)
            NSColor.controlAccentColor.setFill()
            underline.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Close Tab", action: #selector(closeFromMenu), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func closeFromMenu() { onClose?() }

    override func mouseDragged(with event: NSEvent) {
        let pb = NSPasteboardItem()
        pb.setString(tab.id.uuidString, forType: .string)
        let item = NSDraggingItem(pasteboardWriter: pb)
        item.setDraggingFrame(bounds, contents: snapshot())
        let session = beginDraggingSession(with: [item], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = false
    }

    private func snapshot() -> NSImage {
        let rep = bitmapImageRepForCachingDisplay(in: bounds)!
        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = label.intrinsicContentSize
        return NSSize(width: labelSize.width + 24, height: 28)
    }

    func setActive(_ active: Bool) {
        isActive = active
        label.textColor = active ? .labelColor : .secondaryLabelColor
    }
}

extension TabBarItemView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .generic
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard let window = self.window else { return }
        let windowFrame = window.frame
        if !NSPointInRect(screenPoint, windowFrame) {
            NSAnimationEffect.poof.show(centeredAt: screenPoint, size: NSSize(width: 32, height: 32))
            onClose?()
        }
    }
}
