import CoreGraphics
import Foundation

public struct Store: Codable, Equatable, Sendable {
    public var tabs: [TabRef]
    public var activeTabID: UUID
    public var theme: Theme
    public var floatOnTop: Bool
    public var hideDefaultDoc: Bool
    public var windowFrame: CGRect?

    public init(
        tabs: [TabRef],
        activeTabID: UUID,
        theme: Theme = .defaultTheme,
        floatOnTop: Bool = false,
        hideDefaultDoc: Bool = false,
        windowFrame: CGRect? = nil
    ) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.theme = theme
        self.floatOnTop = floatOnTop
        self.hideDefaultDoc = hideDefaultDoc
        self.windowFrame = windowFrame
    }

    public static var defaultStore: Store {
        let bundled = TabRef.bundled
        return Store(tabs: [bundled], activeTabID: bundled.id)
    }
}
