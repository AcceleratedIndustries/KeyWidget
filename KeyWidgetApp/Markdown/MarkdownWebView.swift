import AppKit
import WebKit
import KeyWidgetShared
import os

final class MarkdownWebView: NSView, WKNavigationDelegate {
    let webView: DropAwareWebView
    private let findBar = FindBar()
    private let renderer = MarkdownRenderer()
    private var currentTheme: Theme = .iaWriter
    private let log = Logger(subsystem: "com.williamappleton.keywidget", category: "MarkdownWebView")

    var onDrop: (([URL]) -> Void)?

    override init(frame frameRect: NSRect) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = DropAwareWebView(frame: .zero, configuration: config)
        super.init(frame: frameRect)

        findBar.translatesAutoresizingMaskIntoConstraints = false
        findBar.isHidden = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(findBar)
        addSubview(webView)
        NSLayoutConstraint.activate([
            findBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            findBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            findBar.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        updateWebViewTopConstraint()

        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        webView.navigationDelegate = self
        webView.onFileDrop = { [weak self] urls in self?.onDrop?(urls) }

        findBar.onQueryChange = { [weak self] q in self?.search(q, backwards: false, startOver: true) }
        findBar.onNext = { [weak self] in self?.search(self?.findBar.query ?? "", backwards: false, startOver: false) }
        findBar.onPrev = { [weak self] in self?.search(self?.findBar.query ?? "", backwards: true, startOver: false) }
        findBar.onClose = { [weak self] in self?.hideFindBar() }
    }

    required init?(coder: NSCoder) { fatalError() }

    private var webViewTopConstraint: NSLayoutConstraint?

    private func updateWebViewTopConstraint() {
        webViewTopConstraint?.isActive = false
        let anchor = findBar.isHidden ? topAnchor : findBar.bottomAnchor
        let c = webView.topAnchor.constraint(equalTo: anchor)
        c.isActive = true
        webViewTopConstraint = c
    }

    func showFindBar() {
        findBar.isHidden = false
        updateWebViewTopConstraint()
        findBar.focus()
    }

    func hideFindBar() {
        findBar.isHidden = true
        updateWebViewTopConstraint()
        findBar.setStatus("")
        // Clear WKWebView highlight by searching for an empty string
        webView.evaluateJavaScript("window.getSelection().removeAllRanges()", completionHandler: nil)
        window?.makeFirstResponder(webView)
    }

    private func search(_ query: String, backwards: Bool, startOver: Bool) {
        guard !query.isEmpty else {
            findBar.setStatus("")
            return
        }
        let config = WKFindConfiguration()
        config.backwards = backwards
        config.wraps = true
        config.caseSensitive = false
        webView.find(query, configuration: config) { [weak self] result in
            self?.findBar.setStatus(result.matchFound ? "" : "Not found")
        }
    }

    func zoomIn()   { webView.pageZoom = min(webView.pageZoom + 0.1, 3.0) }
    func zoomOut()  { webView.pageZoom = max(webView.pageZoom - 0.1, 0.5) }
    func zoomReset() { webView.pageZoom = 1.0 }

    func loadMarkdown(_ markdown: String, theme: Theme, baseURL: URL? = nil) {
        self.currentTheme = theme
        let body = renderer.render(markdown: markdown)
        let html = Self.wrap(body: body, theme: theme)
        do {
            let tmpDir = FileManager.default.temporaryDirectory
            let fileURL = tmpDir.appendingPathComponent("keywidget-render.html")
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            let accessRoot = baseURL ?? tmpDir
            webView.loadFileURL(fileURL, allowingReadAccessTo: accessRoot)
        } catch {
            log.error("write HTML failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func apply(theme: Theme) {
        self.currentTheme = theme
        let js = "document.documentElement.className = 'theme-\(theme.rawValue)';"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - WKNavigationDelegate

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
        <html class="theme-\(theme.rawValue)">
        <head>
          <meta charset="utf-8"/>
          <meta name="viewport" content="width=device-width,initial-scale=1"/>
          <style>\(sharedCSS)\n\(linearCSS)\n\(iaWriterCSS)\n\(monoCSS)</style>
        </head>
        <body>
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

/// WKWebView subclass that lets us handle file-URL drops. WKWebView registers
/// its own drag types on every navigation; the only reliable way to intercept
/// drops on the webview's surface is to override the NSDraggingDestination
/// methods directly on the WKWebView subclass.
final class DropAwareWebView: WKWebView {
    var onFileDrop: (([URL]) -> Void)?

    override init(frame frameRect: NSRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frameRect, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !fileURLs(from: sender).isEmpty { return .copy }
        return super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if !fileURLs(from: sender).isEmpty { return .copy }
        return super.draggingUpdated(sender)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let ok = !fileURLs(from: sender).isEmpty
        return ok || super.prepareForDragOperation(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        if !urls.isEmpty {
            onFileDrop?(urls)
            return true
        }
        return super.performDragOperation(sender)
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else { return [] }
        return urls.filter { ["md","markdown","mdown","mdx"].contains($0.pathExtension.lowercased()) }
    }
}
