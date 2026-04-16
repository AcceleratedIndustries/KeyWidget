import Foundation
import Markdown

public enum MarkdownPreview {
    public static func extract(from markdown: String, maxLines: Int = 10) -> (title: String, preview: String) {
        let document = Document(parsing: markdown)
        var title: String?
        var previewParts: [String] = []

        for child in document.children {
            if title == nil, let heading = child as? Heading, heading.level == 1 {
                title = plainText(of: heading).trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            let text: String
            switch child {
            case let paragraph as Paragraph:
                text = plainText(of: paragraph)
            case let heading as Heading:
                text = plainText(of: heading)
            default:
                text = ""
            }
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                previewParts.append(cleaned)
                if previewParts.count >= maxLines { break }
            }
        }

        let resolvedTitle = title
            ?? markdown.split(separator: "\n").first.map { String($0) }
            ?? ""
        let preview = previewParts.prefix(maxLines).joined(separator: "\n")
        return (resolvedTitle, preview)
    }

    /// Walk a markup node, accumulating text content from inline text and code
    /// spans. This strips markdown formatting (emphasis, strong, backticks,
    /// link/image syntax) while preserving the underlying characters a human
    /// would read.
    private static func plainText(of markup: any Markup) -> String {
        var out = ""
        collectPlainText(from: markup, into: &out)
        return out
    }

    private static func collectPlainText(from markup: any Markup, into out: inout String) {
        switch markup {
        case let text as Text:
            out += text.string
        case let code as InlineCode:
            out += code.code
        case let softBreak as SoftBreak:
            _ = softBreak
            out += " "
        case let lineBreak as LineBreak:
            _ = lineBreak
            out += " "
        default:
            for child in markup.children {
                collectPlainText(from: child, into: &out)
            }
        }
    }
}
