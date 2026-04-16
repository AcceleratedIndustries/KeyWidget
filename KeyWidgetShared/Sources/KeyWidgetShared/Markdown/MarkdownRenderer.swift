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
        rawHTMLSuppressionDepth = 0
        return defaultVisit(document)
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        rawHTMLSuppressionDepth = 0
        let level = max(1, min(6, heading.level))
        return "<h\(level)>\(defaultVisit(heading))</h\(level)>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        rawHTMLSuppressionDepth = 0
        return "<p>\(defaultVisit(paragraph))</p>"
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
        let inner = defaultVisit(link)
        let raw = link.destination ?? ""
        guard let safe = sanitizedURL(raw) else {
            // Scheme not allowed — drop the anchor, render inner text only.
            return inner
        }
        let dest = escapeAttribute(safe)
        return "<a href=\"\(dest)\" target=\"_blank\" rel=\"noopener\">\(inner)</a>"
    }

    mutating func visitImage(_ image: Image) -> String {
        let raw = image.source ?? ""
        let alt = escapeAttribute(image.plainText)
        guard let safe = sanitizedURL(raw) else {
            // Scheme not allowed — drop the image entirely.
            return ""
        }
        let src = escapeAttribute(safe)
        return "<img src=\"\(src)\" alt=\"\(alt)\"/>"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> String {
        "<ul>\(defaultVisit(list))</ul>"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> String {
        "<ol>\(defaultVisit(list))</ol>"
    }

    mutating func visitListItem(_ item: ListItem) -> String {
        rawHTMLSuppressionDepth = 0
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
        rawHTMLSuppressionDepth = 0
        return "<blockquote>\(defaultVisit(quote))</blockquote>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        rawHTMLSuppressionDepth = 0
        let lang = codeBlock.language.map { " class=\"language-\(escapeAttribute($0))\"" } ?? ""
        return "<pre><code\(lang)>\(escapeHTML(codeBlock.code))</code></pre>"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        rawHTMLSuppressionDepth = 0
        return "<hr/>"
    }

    mutating func visitTable(_ table: Table) -> String {
        rawHTMLSuppressionDepth = 0
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
        escapeHTML(s)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func isOpeningTag(_ raw: String) -> Bool {
        guard raw.hasPrefix("<"), raw.hasSuffix(">") else { return false }
        if raw.hasPrefix("</") { return false }
        if raw.hasPrefix("<!") || raw.hasPrefix("<?") { return false }
        // Self-closing: `<br/>` or `<br />` — tolerate trailing whitespace before `>`.
        let beforeClose = String(raw.dropLast()).trimmingCharacters(in: .whitespaces)
        if beforeClose.hasSuffix("/") { return false }
        // HTML5 void elements never open a suppression scope; they're neutral.
        if let name = tagElementName(raw),
           Self.voidElements.contains(name.lowercased()) {
            return false
        }
        return true
    }

    private func isClosingTag(_ raw: String) -> Bool {
        raw.hasPrefix("</") && raw.hasSuffix(">")
    }

    /// Extract the element name from a raw tag string. Returns `nil` if the
    /// input doesn't look like an opening tag.
    private func tagElementName(_ raw: String) -> String? {
        guard raw.hasPrefix("<"), !raw.hasPrefix("</"),
              !raw.hasPrefix("<!"), !raw.hasPrefix("<?") else {
            return nil
        }
        // Skip the leading '<'
        let afterLT = raw.dropFirst()
        var name = ""
        for ch in afterLT {
            if ch.isWhitespace || ch == ">" || ch == "/" { break }
            name.append(ch)
        }
        return name.isEmpty ? nil : name
    }

    /// HTML5 void elements — self-closing semantics, even when written without `/`.
    private static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr"
    ]

    /// URL schemes permitted in `href` / `src`. Relative URLs (no scheme) are
    /// always allowed. Anything else — including `javascript:` and `data:` —
    /// is dropped to prevent XSS.
    private static let allowedSchemes: Set<String> = [
        "http", "https", "mailto", "keywidget"
    ]

    /// Returns the input URL string if its scheme is acceptable (or absent —
    /// i.e. a relative URL), otherwise `nil`.
    private func sanitizedURL(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return trimmed }
        // Match RFC 3986 scheme: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) ":"
        let schemePattern = "^[a-zA-Z][a-zA-Z0-9+.\\-]*:"
        if let range = trimmed.range(of: schemePattern, options: .regularExpression) {
            let scheme = String(trimmed[range]).dropLast().lowercased() // drop trailing ':'
            if Self.allowedSchemes.contains(String(scheme)) {
                return trimmed
            }
            return nil
        }
        // No scheme — treat as a relative URL and allow it.
        return trimmed
    }
}
