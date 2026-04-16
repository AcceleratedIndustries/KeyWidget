import Foundation

public enum DeepLink: Equatable, Sendable {
    case openApp
    case openTab(UUID)

    public static let scheme = "keywidget"

    public static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == scheme else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        if let tabParam = queryItems.first(where: { $0.name == "tab" })?.value {
            guard let uuid = UUID(uuidString: tabParam) else { return nil }
            return .openTab(uuid)
        }
        return .openApp
    }

    public static func openTabURL(id: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "tab", value: id.uuidString)]
        return components.url!
    }
}
