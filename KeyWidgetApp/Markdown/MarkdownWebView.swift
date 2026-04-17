import AppKit
import WebKit
import KeyWidgetShared
import os

final class MarkdownWebView: NSView, WKNavigationDelegate {
    let webView: WKWebView
    private let renderer = MarkdownRenderer()
    private var currentTheme: Theme = .iaWriter
    private let log = Logger(subsystem: "com.williamappleton.keywidget", category: "MarkdownWebView")

    override init(frame frameRect: NSRect) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: frameRect)
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        webView.navigationDelegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func loadMarkdown(_ markdown: String, theme: Theme, baseURL: URL? = nil) {
        self.currentTheme = theme
        let body = renderer.render(markdown: markdown)
        let html = Self.wrap(body: body, theme: theme)
        do {
            let tmpDir = FileManager.default.temporaryDirectory
            let fileURL = tmpDir.appendingPathComponent("keywidget-render.html")
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            let accessRoot = baseURL ?? tmpDir
            log.info("loadFileURL \(fileURL.path, privacy: .public) accessRoot=\(accessRoot.path, privacy: .public)")
            webView.loadFileURL(fileURL, allowingReadAccessTo: accessRoot)
        } catch {
            log.error("write HTML failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func apply(theme: Theme) {
        self.currentTheme = theme
        let js = "document.body.className = 'theme-\(theme.rawValue)';"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        log.info("didFinish")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log.error("didFail: \(error.localizedDescription, privacy: .public)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        log.error("didFailProvisional: \(error.localizedDescription, privacy: .public)")
    }

    private static func wrap(body: String, theme: Theme) -> String {
        let sharedCSS = readCSS("shared")
        let linearCSS = readCSS("linear")
        let iaWriterCSS = readCSS("iaWriter")
        let monoCSS = readCSS("mono")
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width,initial-scale=1"/>
          <style>\(sharedCSS)\n\(linearCSS)\n\(iaWriterCSS)\n\(monoCSS)</style>
        </head>
        <body class="theme-\(theme.rawValue)">
          \(body)
        </body>
        </html>
        """
    }

    private static func readCSS(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "css"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return css
    }
}
