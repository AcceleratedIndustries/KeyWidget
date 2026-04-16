import XCTest
@testable import KeyWidgetShared

final class DeepLinkTests: XCTestCase {

    func testParsesOpenTab() {
        let uuid = UUID()
        let url = URL(string: "keywidget://open?tab=\(uuid.uuidString)")!
        XCTAssertEqual(DeepLink.parse(url), .openTab(uuid))
    }

    func testReturnsOpenAppWhenNoTabParam() {
        let url = URL(string: "keywidget://open")!
        XCTAssertEqual(DeepLink.parse(url), .openApp)
    }

    func testReturnsNilForUnknownScheme() {
        let url = URL(string: "https://example.com")!
        XCTAssertNil(DeepLink.parse(url))
    }

    func testReturnsNilForMalformedTabUUID() {
        let url = URL(string: "keywidget://open?tab=not-a-uuid")!
        XCTAssertNil(DeepLink.parse(url))
    }

    func testBuildsOpenTabURL() {
        let uuid = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let url = DeepLink.openTabURL(id: uuid)
        XCTAssertEqual(url.absoluteString, "keywidget://open?tab=11111111-2222-3333-4444-555555555555")
    }
}
