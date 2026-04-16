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
}
