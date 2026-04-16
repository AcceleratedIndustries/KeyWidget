import XCTest
@testable import KeyWidgetShared

final class MarkdownPreviewTests: XCTestCase {

    func testExtractsFirstHeadingAsTitle() {
        let (title, _) = MarkdownPreview.extract(from: "# macOS Keys\n\nbody")
        XCTAssertEqual(title, "macOS Keys")
    }

    func testFallsBackToFirstLineWhenNoHeading() {
        let (title, _) = MarkdownPreview.extract(from: "Just some text.")
        XCTAssertEqual(title, "Just some text.")
    }

    func testStripsFormattingFromPreview() {
        let (_, preview) = MarkdownPreview.extract(from: "# T\n\n**bold** and `code`\n\nmore")
        XCTAssertTrue(preview.contains("bold and code"))
        XCTAssertFalse(preview.contains("**"))
        XCTAssertFalse(preview.contains("`"))
    }

    func testPreviewLimitedByLineCount() {
        let body = (1...20).map { "line \($0)" }.joined(separator: "\n")
        let (_, preview) = MarkdownPreview.extract(from: body, maxLines: 3)
        let lines = preview.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertLessThanOrEqual(lines.count, 3)
    }
}
