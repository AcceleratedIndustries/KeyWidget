import AppKit

final class MissingFileViewController: NSViewController {
    var pathHint: String = ""
    var onLocate: (() -> Void)?
    var onRemove: (() -> Void)?

    override func loadView() {
        let v = NSView()
        v.wantsLayer = true
        view = v

        let title = NSTextField(labelWithString: "Couldn't find this file")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "\(pathHint) — it may have moved or been deleted.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingMiddle

        let locate = NSButton(title: "Locate…", target: self, action: #selector(locate))
        let remove = NSButton(title: "Remove Tab", target: self, action: #selector(remove))

        let stack = NSStackView(views: [title, subtitle, NSStackView(views: [locate, remove])])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: v.widthAnchor, multiplier: 0.8),
        ])
    }

    @objc private func locate() { onLocate?() }
    @objc private func remove() { onRemove?() }
}
