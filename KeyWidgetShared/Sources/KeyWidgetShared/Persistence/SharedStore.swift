import Foundation

public final class SharedStore {
    public static let appGroupID = "group.com.williamappleton.keywidget"
    public static let storeKey = "com.williamappleton.keywidget.store"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public convenience init() {
        let suite = UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard
        self.init(defaults: suite)
    }

    public func load() -> Store {
        guard let data = defaults.data(forKey: SharedStore.storeKey) else {
            return .defaultStore
        }
        return (try? JSONDecoder().decode(Store.self, from: data)) ?? .defaultStore
    }

    public func save(_ store: Store) throws {
        let data = try JSONEncoder().encode(store)
        defaults.set(data, forKey: SharedStore.storeKey)
    }
}
