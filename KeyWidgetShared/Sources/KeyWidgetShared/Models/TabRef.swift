import Foundation

public enum TabKind: String, Codable, Equatable, Sendable {
    case bundled
    case userFile
}

public struct TabRef: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: TabKind
    public var bookmark: Data?
    public var displayTitle: String

    public init(id: UUID = UUID(), kind: TabKind, bookmark: Data?, displayTitle: String) {
        self.id = id
        self.kind = kind
        self.bookmark = bookmark
        self.displayTitle = displayTitle
    }

    public static let bundledID = UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!

    public static var bundled: TabRef {
        TabRef(id: bundledID, kind: .bundled, bookmark: nil, displayTitle: "macOS Keybindings")
    }
}
