import Foundation
import Markdown

public struct MarkdownRenderer: Sendable {

    public init() {}

    public func render(markdown: String) -> String {
        let document = Document(
            parsing: markdown,
            options: [.parseBlockDirectives]
        )
        var visitor = HTMLVisitor()
        return visitor.visit(document)
    }
}

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    /// Depth of raw HTML tag suppression. While > 0, text and inline content
    /// are swallowed so that the bodies of raw HTML tags (e.g. `<script>…</script>`)
    /// do not leak through.
    private var rawHTMLSuppressionDepth: Int = 0

    mutating func defaultVisit(_ markup: any Markup) -> String {
        var out = ""
        for child in markup.children {
            out += visit(child)
        }
        return out
    }

    mutating func visitDocument(_ document: Document) -> String {
        defaultVisit(document)
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = max(1, min(6, heading.level))
        return "<h\(level)>\(defaultVisit(heading))</h\(level)>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(defaultVisit(paragraph))</p>"
    }

    mutating func visitText(_ text: Text) -> String {
        if rawHTMLSuppressionDepth > 0 { return "" }
        return escapeHTML(text.string)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let inner = defaultVisit(emphasis)
        if rawHTMLSuppressionDepth > 0 { return "" }
        return "<em>\(inner)</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        let inner = defaultVisit(strong)
        if rawHTMLSuppressionDepth > 0 { return "" }
        return "<strong>\(inner)</strong>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        if rawHTMLSuppressionDepth > 0 { return "" }
        return "<kbd>\(escapeHTML(inlineCode.code))</kbd>"
    }

    mutating func visitLink(_ link: Link) -> String {
        let dest = escapeAttribute(link.destination ?? "")
        return "<a href=\"\(dest)\" target=\"_blank\" rel=\"noopener\">\(defaultVisit(link))</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let src = escapeAttribute(image.source ?? "")
        let alt = escapeAttribute(image.plainText)
        return "<img src=\"\(src)\" alt=\"\(alt)\"/>"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> String {
        "<ul>\(defaultVisit(list))</ul>"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> String {
        "<ol>\(defaultVisit(list))</ol>"
    }

    mutating func visitListItem(_ item: ListItem) -> String {
        let checkbox: String
        switch item.checkbox {
        case .checked:
            checkbox = "<input type=\"checkbox\" checked disabled/> "
        case .unchecked:
            checkbox = "<input type=\"checkbox\" disabled/> "
        case .none:
            checkbox = ""
        @unknown default:
            checkbox = ""
        }
        return "<li>\(checkbox)\(unwrapSingleParagraph(item))</li>"
    }

    mutating func visitBlockQuote(_ quote: BlockQuote) -> String {
        "<blockquote>\(defaultVisit(quote))</blockquote>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let lang = codeBlock.language.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
        return "<pre><code\(lang)>\(escapeHTML(codeBlock.code))</code></pre>"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr/>"
    }

    mutating func visitTable(_ table: Table) -> String {
        var head = ""
        for cell in table.head.cells {
            head += "<th>\(defaultVisit(cell))</th>"
        }
        var body = ""
        for row in table.body.rows {
            body += "<tr>"
            for cell in row.cells {
                body += "<td>\(defaultVisit(cell))</td>"
            }
            body += "</tr>"
        }
        return "<table><thead><tr>\(head)</tr></thead><tbody>\(body)</tbody></table>"
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> String {
        ""
    }

    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> String {
        let raw = inlineHTML.rawHTML
        if isClosingTag(raw) {
            if rawHTMLSuppressionDepth > 0 {
                rawHTMLSuppressionDepth -= 1
            }
        } else if isOpeningTag(raw) {
            rawHTMLSuppressionDepth += 1
        }
        // Self-closing tags and comments neither open nor close a suppression range;
        // they simply produce no output.
        return ""
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br/>"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        " "
    }

    private mutating func unwrapSingleParagraph(_ item: ListItem) -> String {
        if item.childCount == 1, let paragraph = item.child(at: 0) as? Paragraph {
            return defaultVisit(paragraph)
        }
        return defaultVisit(item)
    }

    private func escapeHTML(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            default: out.append(ch)
            }
        }
        return out
    }

    private func escapeAttribute(_ s: String) -> String {
        escapeHTML(s).replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func isOpeningTag(_ raw: String) -> Bool {
        guard raw.hasPrefix("<"), raw.hasSuffix(">") else { return false }
        if raw.hasPrefix("</") { return false }
        if raw.hasPrefix("<!") || raw.hasPrefix("<?") { return false }
        // Self-closing: `<br/>` or `<br />`
        let beforeClose = raw.dropLast()
        if beforeClose.hasSuffix("/") { return false }
        return true
    }

    private func isClosingTag(_ raw: String) -> Bool {
        raw.hasPrefix("</") && raw.hasSuffix(">")
    }
}
