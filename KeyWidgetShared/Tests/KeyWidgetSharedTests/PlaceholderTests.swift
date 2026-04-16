import XCTest
@testable import KeyWidgetShared

final class PlaceholderTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(KeyWidgetShared.version.isEmpty)
    }
}
