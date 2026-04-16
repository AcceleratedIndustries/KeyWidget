import XCTest
@testable import KeyWidgetShared

final class SharedStoreTests: XCTestCase {

    private var testSuiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testSuiteName = "test.keywidget.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: testSuiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: testSuiteName)
        super.tearDown()
    }

    func testLoadReturnsDefaultStoreWhenNothingStored() {
        let store = SharedStore(defaults: defaults)
        XCTAssertEqual(store.load(), Store.defaultStore)
    }

    func testSaveThenLoadRoundTrips() throws {
        let store = SharedStore(defaults: defaults)
        var value = Store.defaultStore
        value.theme = .mono
        value.floatOnTop = true
        try store.save(value)

        let loaded = store.load()
        XCTAssertEqual(loaded, value)
    }

    func testLoadReturnsDefaultOnCorruptData() {
        defaults.set(Data([0xFF, 0xFF]), forKey: SharedStore.storeKey)
        let store = SharedStore(defaults: defaults)
        XCTAssertEqual(store.load(), Store.defaultStore)
    }
}
