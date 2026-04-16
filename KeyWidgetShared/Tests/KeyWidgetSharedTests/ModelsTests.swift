import XCTest
@testable import KeyWidgetShared

final class ModelsTests: XCTestCase {

    func testThemeEncodesAsRawString() throws {
        let theme = Theme.iaWriter
        let data = try JSONEncoder().encode(theme)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"iaWriter\"")
    }

    func testThemeDefaultIsIAWriter() {
        XCTAssertEqual(Theme.defaultTheme, .iaWriter)
    }

    func testTabRefRoundTrips() throws {
        let original = TabRef(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            kind: .bundled,
            bookmark: nil,
            displayTitle: "macOS Keybindings"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TabRef.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testStoreDefaultHasBundledTabOnly() {
        let store = Store.defaultStore
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.tabs[0].kind, .bundled)
        XCTAssertEqual(store.activeTabID, store.tabs[0].id)
        XCTAssertEqual(store.theme, .iaWriter)
        XCTAssertFalse(store.floatOnTop)
        XCTAssertFalse(store.hideDefaultDoc)
    }

    func testStoreRoundTrips() throws {
        let original = Store.defaultStore
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Store.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
