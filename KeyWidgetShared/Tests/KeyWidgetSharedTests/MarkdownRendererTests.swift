import XCTest
@testable import KeyWidgetShared

final class MarkdownRendererTests: XCTestCase {

    private func render(_ markdown: String) -> String {
        MarkdownRenderer().render(markdown: markdown)
    }

    func testRendersH1() {
        XCTAssertEqual(render("# Title"), "<h1>Title</h1>")
    }

    func testRendersH2AndH3() {
        XCTAssertEqual(render("## Section"), "<h2>Section</h2>")
        XCTAssertEqual(render("### Sub"), "<h3>Sub</h3>")
    }

    func testRendersParagraph() {
        XCTAssertEqual(render("Hello world."), "<p>Hello world.</p>")
    }

    func testRendersInlineCodeAsKbd() {
        XCTAssertEqual(render("Press `⌘`"), "<p>Press <kbd>⌘</kbd></p>")
    }

    func testRendersStrongAndEm() {
        XCTAssertEqual(render("**bold** and *italic*"),
                       "<p><strong>bold</strong> and <em>italic</em></p>")
    }

    func testRendersUnorderedList() {
        let html = render("- one\n- two")
        XCTAssertEqual(html, "<ul><li>one</li><li>two</li></ul>")
    }

    func testRendersOrderedList() {
        let html = render("1. one\n2. two")
        XCTAssertEqual(html, "<ol><li>one</li><li>two</li></ol>")
    }

    func testRendersLink() {
        XCTAssertEqual(render("[Apple](https://apple.com)"),
                       "<p><a href=\"https://apple.com\" target=\"_blank\" rel=\"noopener\">Apple</a></p>")
    }

    func testRendersBlockquote() {
        let html = render("> quoted")
        XCTAssertEqual(html, "<blockquote><p>quoted</p></blockquote>")
    }

    func testRendersCodeBlockWithLanguage() {
        let html = render("```swift\nlet x = 1\n```")
        XCTAssertEqual(html, "<pre><code class=\"language-swift\">let x = 1\n</code></pre>")
    }

    func testRendersCodeBlockWithoutLanguage() {
        let html = render("```\nplain\n```")
        XCTAssertEqual(html, "<pre><code>plain\n</code></pre>")
    }

    func testRendersThematicBreak() {
        XCTAssertEqual(render("---"), "<hr/>")
    }

    func testRendersTable() {
        let md = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        let html = render(md)
        XCTAssertEqual(html,
            "<table><thead><tr><th>A</th><th>B</th></tr></thead><tbody><tr><td>1</td><td>2</td></tr></tbody></table>"
        )
    }

    func testRendersTaskList() {
        let md = "- [x] done\n- [ ] todo"
        let html = render(md)
        XCTAssertEqual(html,
            "<ul><li><input type=\"checkbox\" checked disabled/> done</li><li><input type=\"checkbox\" disabled/> todo</li></ul>"
        )
    }

    func testStripsRawHTML() {
        let html = render("Hello <script>alert(1)</script>")
        XCTAssertEqual(html, "<p>Hello </p>")
    }

    func testRendersImage() {
        let html = render("![alt](image.png)")
        XCTAssertEqual(html, "<p><img src=\"image.png\" alt=\"alt\"/></p>")
    }

    func testEscapesHTMLInText() {
        XCTAssertEqual(render("a < b & c > d"),
                       "<p>a &lt; b &amp; c &gt; d</p>")
    }

    // MARK: - Issue 1: Block-scoped raw HTML suppression

    func testUnclosedRawHTMLDoesNotSwallowSubsequentBlocks() {
        let md = "<unclosed>Para 1\n\nPara 2"
        let html = MarkdownRenderer().render(markdown: md)
        // The `<unclosed>` tag is stripped; "Para 1" is suppressed because it follows the open tag in the same block.
        // BUT: the second paragraph must render normally — depth is reset at block boundaries.
        XCTAssertTrue(html.contains("<p>Para 2</p>"),
                      "Expected 'Para 2' to render after unbalanced open tag. Got: \(html)")
    }

    // MARK: - Issue 2: Void elements and whitespace in self-closing tags

    func testVoidHTMLElementsDoNotLeakSuppression() {
        let md = "before<br>middle<br />after"
        let html = MarkdownRenderer().render(markdown: md)
        // All three literal text pieces should be present; <br> and <br /> are void and shouldn't trigger suppression.
        XCTAssertTrue(html.contains("before"), "Got: \(html)")
        XCTAssertTrue(html.contains("middle"), "Got: \(html)")
        XCTAssertTrue(html.contains("after"), "Got: \(html)")
    }

    // MARK: - Issue 3: Attribute escaping of single quotes

    func testEscapeAttributeHandlesSingleQuote() {
        let html = MarkdownRenderer().render(markdown: "[x](https://example.com/?q=it's)")
        XCTAssertFalse(html.contains("'"),
                       "Single quote should be escaped in href. Got: \(html)")
        XCTAssertTrue(html.contains("&#39;"), "Got: \(html)")
    }

    // MARK: - Issue 4: URL scheme allowlist

    func testRejectsJavaScriptURLsInLinks() {
        let html = MarkdownRenderer().render(markdown: "[click](javascript:alert(1))")
        XCTAssertFalse(html.contains("javascript:"), "javascript: scheme should be blocked. Got: \(html)")
    }

    func testAllowsHttpAndHttpsLinks() {
        let httpHTML = MarkdownRenderer().render(markdown: "[a](http://example.com)")
        XCTAssertTrue(httpHTML.contains("href=\"http://example.com\""), "Got: \(httpHTML)")
        let httpsHTML = MarkdownRenderer().render(markdown: "[b](https://example.com)")
        XCTAssertTrue(httpsHTML.contains("href=\"https://example.com\""), "Got: \(httpsHTML)")
    }

    func testAllowsRelativeURLs() {
        let html = MarkdownRenderer().render(markdown: "[c](./path/to/page.html)")
        XCTAssertTrue(html.contains("href=\"./path/to/page.html\""), "Got: \(html)")
    }

    func testRejectsDataURLInImage() {
        let html = MarkdownRenderer().render(markdown: "![x](data:text/html,<script>alert(1)</script>)")
        XCTAssertFalse(html.contains("data:"), "data: URLs should be blocked in images. Got: \(html)")
    }
}
