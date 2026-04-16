import AppKit
import KeyWidgetShared

final class TabBarItemView: NSView {
    let tab: TabRef
    var isActive: Bool = false { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

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

    override var intrinsicContentSize: NSSize {
        let labelSize = label.intrinsicContentSize
        return NSSize(width: labelSize.width + 24, height: 28)
    }

    func setActive(_ active: Bool) {
        isActive = active
        label.textColor = active ? .labelColor : .secondaryLabelColor
    }
}
