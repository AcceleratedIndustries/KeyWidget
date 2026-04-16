import Foundation

public enum Theme: String, Codable, CaseIterable, Equatable, Sendable {
    case linear
    case iaWriter
    case mono

    public static let defaultTheme: Theme = .iaWriter

    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .iaWriter: return "iA Writer"
        case .mono: return "Mono"
        }
    }
}
