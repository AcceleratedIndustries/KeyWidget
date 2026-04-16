# KeyWidget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the macOS KeyWidget app (tabbed markdown reference viewer with three themes and a float-on-top mode) and its companion WidgetKit desktop tile, per `docs/superpowers/specs/2026-04-16-keywidget-design.md`.

**Architecture:** Single Xcode project with three targets — `KeyWidgetApp` (AppKit + SwiftUI macOS app), `KeyWidgetWidget` (WidgetKit extension), and a shared Swift package `KeyWidgetShared` (models, store, deep link, markdown renderer) linked by both. State is written by the app, read by both, persisted in an App Group `UserDefaults` suite. Markdown is parsed with `swift-markdown` into our own HTML and rendered in a `WKWebView` with CSS-variable-based theming.

**Tech Stack:** Swift 6, macOS 14 (Sonoma) minimum, SwiftUI + AppKit interop, WKWebView, WidgetKit, swift-markdown (Apple), security-scoped bookmarks, App Group UserDefaults.

**Bundle identifiers used in this plan:**
- App: `com.williamappleton.keywidget`
- Widget: `com.williamappleton.keywidget.widget`
- App Group: `group.com.williamappleton.keywidget`

Change these if the final team ID / naming differs, but keep them consistent across the project.

**Scope deferrals from the spec:**
- **Launch at login** is listed in the spec's Preferences section as a toggle. It requires registering an `SMAppService.mainApp` helper and is genuinely tangential to v1's core flow. This plan **defers** it. To add later: one new Preferences toggle, one call to `SMAppService.mainApp.register()` / `.unregister()`, and the `com.apple.developer.service-management.managed-by-main-app` entitlement. No schema or architectural changes needed.

---

## Task 1: Create the Xcode project and configure basic entitlements

**Files:**
- Create: `KeyWidget.xcodeproj/` (via Xcode GUI)
- Create: `KeyWidgetApp/App.swift`
- Create: `KeyWidgetApp/AppDelegate.swift`
- Create: `KeyWidgetApp/Info.plist` (modify generated)
- Create: `KeyWidgetApp/KeyWidgetApp.entitlements`

- [ ] **Step 1: Create the macOS App project in Xcode**

Open Xcode. File → New → Project → macOS → App.
- Product Name: `KeyWidget`
- Team: (your team)
- Organization Identifier: `com.williamappleton`
- Bundle Identifier (auto): `com.williamappleton.keywidget`
- Interface: **SwiftUI**
- Language: Swift
- Storage: None
- Include Tests: **checked**

Save to `/Users/will/src/KeyWidget/`. Xcode will create `KeyWidget.xcodeproj` and a `KeyWidget/` source folder.

**Rename** the source folder from `KeyWidget/` to `KeyWidgetApp/` in Finder, then update the Xcode project to point to the new folder name: right-click the group → Show File Inspector → update the folder path. (Or just rename the group in Xcode, keeping the folder name in sync.)

- [ ] **Step 2: Set deployment target to macOS 14**

Project navigator → `KeyWidget` target → General tab → Minimum Deployments → macOS 14.0.

- [ ] **Step 3: Replace the generated `KeyWidgetApp.swift` with our app + delegate**

Delete the generated `ContentView.swift`. Replace `KeyWidgetApp.swift` with two files:

`KeyWidgetApp/App.swift`:
```swift
import SwiftUI

@main
struct KeyWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Preferences placeholder")
                .frame(width: 420, height: 300)
        }
    }
}
```

`KeyWidgetApp/AppDelegate.swift`:
```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyWidget"
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindow?.makeKeyAndOrderFront(nil) }
        return true
    }
}
```

- [ ] **Step 4: Configure the URL scheme in Info.plist**

Select the `KeyWidget` target → Info tab → URL Types → `+`.
- Identifier: `com.williamappleton.keywidget.urlscheme`
- URL Schemes: `keywidget`
- Role: Viewer

- [ ] **Step 5: Configure App Sandbox entitlements**

Select the target → Signing & Capabilities → `+ Capability` → **App Sandbox**. In the sandbox options enable:
- User Selected File (Read Only)

Then click `+ Capability` again → **App Groups** → `+` → add `group.com.williamappleton.keywidget`.

Open the generated `KeyWidget.entitlements` file and add the bookmarks entitlement manually:
```xml
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

- [ ] **Step 6: Verify build and run**

Run: Product → Build (⌘B). Then ⌘R.
Expected: the app launches and shows an empty window titled "KeyWidget". Close the window, then click the Dock icon — window reopens.

- [ ] **Step 7: Commit**

```bash
cd /Users/will/src/KeyWidget
git add .
git commit -m "feat: scaffold KeyWidget macOS app project"
```

---

## Task 2: Create the KeyWidgetShared Swift package

**Files:**
- Create: `KeyWidgetShared/Package.swift`
- Create: `KeyWidgetShared/Sources/KeyWidgetShared/Placeholder.swift`
- Create: `KeyWidgetShared/Tests/KeyWidgetSharedTests/PlaceholderTests.swift`

- [ ] **Step 1: Create the package directory and manifest**

```bash
cd /Users/will/src/KeyWidget
mkdir -p KeyWidgetShared/Sources/KeyWidgetShared
mkdir -p KeyWidgetShared/Tests/KeyWidgetSharedTests
```

Create `KeyWidgetShared/Package.swift`:
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "KeyWidgetShared",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KeyWidgetShared", targets: ["KeyWidgetShared"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "KeyWidgetShared",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ]
        ),
        .testTarget(
            name: "KeyWidgetSharedTests",
            dependencies: ["KeyWidgetShared"]
        ),
    ]
)
```

- [ ] **Step 2: Write a placeholder source and test so the package compiles**

Create `KeyWidgetShared/Sources/KeyWidgetShared/Placeholder.swift`:
```swift
public enum KeyWidgetShared {
    public static let version = "0.1.0"
}
```

Create `KeyWidgetShared/Tests/KeyWidgetSharedTests/PlaceholderTests.swift`:
```swift
import XCTest
@testable import KeyWidgetShared

final class PlaceholderTests: XCTestCase {
    func testVersionIsNonEmpty() {
        XCTAssertFalse(KeyWidgetShared.version.isEmpty)
    }
}
```

- [ ] **Step 3: Verify the package builds and tests pass**

```bash
cd /Users/will/src/KeyWidget/KeyWidgetShared
swift build
swift test
```

Expected: `Test Suite 'All tests' passed. Executed 1 test`

- [ ] **Step 4: Link the package to the Xcode app target**

In Xcode: File → Add Package Dependencies… → Add Local… → choose `/Users/will/src/KeyWidget/KeyWidgetShared`.
Then select the `KeyWidget` target → General → Frameworks, Libraries, and Embedded Content → `+` → `KeyWidgetShared`.

Verify by adding this line temporarily to `AppDelegate.swift`:
```swift
import KeyWidgetShared
// in applicationDidFinishLaunching, before creating the window:
print("KeyWidgetShared version:", KeyWidgetShared.version)
```

Build and run (⌘R). Expected: console prints `KeyWidgetShared version: 0.1.0`. Then remove the print.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add KeyWidgetShared package with swift-markdown dependency"
```

---

## Task 3: Define Theme, TabRef, and Store models (TDD)

**Files:**
- Create: `KeyWidgetShared/Sources/KeyWidgetShared/Models/Theme.swift`
- Create: `KeyWidgetShared/Sources/KeyWidgetShared/Models/TabRef.swift`
- Create: `KeyWidgetShared/Sources/KeyWidgetShared/Models/Store.swift`
- Create: `KeyWidgetShared/Tests/KeyWidgetSharedTests/ModelsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `KeyWidgetShared/Tests/KeyWidgetSharedTests/ModelsTests.swift`:
```swift
import XCTest
@testable import KeyWidgetShared

final class ModelsTests: XCTestCase {

    func testThemeEncodesAsRawString() throws {
        let theme = Theme.iaWriter
        let data = try JSONEncoder().encode(theme)
        XCTAssertEqual(String(data: data, encoding: .utf8), "\"iaWriter\"")
    }

    func testThemeDefaultIsIAWriter() {
        XCTAssertEqual(Theme.defaultTheme, .iaWriter)
    }

    func testTabRefRoundTrips() throws {
        let original = TabRef(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            kind: .bundled,
            bookmark: nil,
            displayTitle: "macOS Keybindings"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TabRef.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testStoreDefaultHasBundledTabOnly() {
        let store = Store.defaultStore
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.tabs[0].kind, .bundled)
        XCTAssertEqual(store.activeTabID, store.tabs[0].id)
        XCTAssertEqual(store.theme, .iaWriter)
        XCTAssertFalse(store.floatOnTop)
        XCTAssertFalse(store.hideDefaultDoc)
    }

    func testStoreRoundTrips() throws {
        let original = Store.defaultStore
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Store.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
cd /Users/will/src/KeyWidget/KeyWidgetShared
swift test
```

Expected: compile failure — `Theme`, `TabRef`, `Store` are undefined.

- [ ] **Step 3: Implement Theme**

Create `KeyWidgetShared/Sources/KeyWidgetShared/Models/Theme.swift`:
```swift
import Foundation

public enum Theme: String, Codable, CaseIterable, Equatable, Sendable {
    case linear
    case iaWriter
    case mono

    public static let defaultTheme: Theme = .iaWriter

    public var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .iaWriter: return "iA Writer"
        case .mono: return "Mono"
        }
    }
}
```

- [ ] **Step 4: Implement TabRef**

Create `KeyWidgetShared/Sources/KeyWidgetShared/Models/TabRef.swift`:
```swift
import Foundation

public enum TabKind: String, Codable, Equatable, Sendable {
    case bundled
    case userFile
}

public struct TabRef: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: TabKind
    public var bookmark: Data?
    public var displayTitle: String

    public init(id: UUID = UUID(), kind: TabKind, bookmark: Data?, displayTitle: String) {
        self.id = id
        self.kind = kind
        self.bookmark = bookmark
        self.displayTitle = displayTitle
    }

    public static let bundledID = UUID(uuidString: "00000000-0000-0000-0000-00000000CAFE")!

    public static var bundled: TabRef {
        TabRef(id: bundledID, kind: .bundled, bookmark: nil, displayTitle: "macOS Keybindings")
    }
}
```

- [ ] **Step 5: Implement Store**

Create `KeyWidgetShared/Sources/KeyWidgetShared/Models/Store.swift`:
```swift
import CoreGraphics
import Foundation

public struct Store: Codable, Equatable, Sendable {
    public var tabs: [TabRef]
    public var activeTabID: UUID
    public var theme: Theme
    public var floatOnTop: Bool
    public var hideDefaultDoc: Bool
    public var windowFrame: CGRect?

    public init(
        tabs: [TabRef],
        activeTabID: UUID,
        theme: Theme = .defaultTheme,
        floatOnTop: Bool = false,
        hideDefaultDoc: Bool = false,
        windowFrame: CGRect? = nil
    ) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.theme = theme
        self.floatOnTop = floatOnTop
        self.hideDefaultDoc = hideDefaultDoc
        self.windowFrame = windowFrame
    }

    public static var defaultStore: Store {
        let bundled = TabRef.bundled
        return Store(tabs: [bundled], activeTabID: bundled.id)
    }
}
```

Note: the test uses fixed `UUID` for the bundled tab's id check via `Store.defaultStore.tabs[0].id == store.activeTabID`, not a hardcoded match — so the bundled UUID can be any stable value. We fix it at `00000000-0000-0000-0000-00000000CAFE` for consistency.

- [ ] **Step 6: Update the tests to account for the fixed bundled ID**

Edit the first assertion in `testTabRefRoundTrips` to use `TabRef.bundledID` if you prefer symmetry, but the existing test with an arbitrary UUID should still pass.

- [ ] **Step 7: Run the tests**

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add .
git commit -m "feat: add Theme, TabRef, Store models to shared package"
```

---

## Task 4: DeepLink parsing (TDD)

**Files:**
- Create: `KeyWidgetShared/Sources/KeyWidgetShared/DeepLink/DeepLink.swift`
- Create: `KeyWidgetShared/Tests/KeyWidgetSharedTests/DeepLinkTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `KeyWidgetShared/Tests/KeyWidgetSharedTests/DeepLinkTests.swift`:
```swift
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
swift test --filter DeepLinkTests
```

Expected: compile failure — `DeepLink` is undefined.

- [ ] **Step 3: Implement DeepLink**

Create `KeyWidgetShared/Sources/KeyWidgetShared/DeepLink/DeepLink.swift`:
```swift
import Foundation

public enum DeepLink: Equatable, Sendable {
    case openApp
    case openTab(UUID)

    public static let scheme = "keywidget"

    public static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == scheme else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        if let tabParam = queryItems.first(where: { $0.name == "tab" })?.value {
            guard let uuid = UUID(uuidString: tabParam) else { return nil }
            return .openTab(uuid)
        }
        return .openApp
    }

    public static func openTabURL(id: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "tab", value: id.uuidString)]
        return components.url!
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
swift test --filter DeepLinkTests
```

Expected: all DeepLinkTests pass.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add DeepLink parser for keywidget:// URLs"
```

---

## Task 5: SharedStore (App Group UserDefaults accessor, TDD)

**Files:**
- Create: `KeyWidgetShared/Sources/KeyWidgetShared/Persistence/SharedStore.swift`
- Create: `KeyWidgetShared/Tests/KeyWidgetSharedTests/SharedStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `KeyWidgetShared/Tests/KeyWidgetSharedTests/SharedStoreTests.swift`:
```swift
import XCTest
@testable import KeyWidgetShared

final class SharedStoreTests: XCTestCase {

    private var testSuiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testSuiteName = "test.keywidget.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: testSuiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: testSuiteName)
        super.tearDown()
    }

    func testLoadReturnsDefaultStoreWhenNothingStored() {
        let store = SharedStore(defaults: defaults)
        XCTAssertEqual(store.load(), Store.defaultStore)
    }

    func testSaveThenLoadRoundTrips() throws {
        let store = SharedStore(defaults: defaults)
        var value = Store.defaultStore
        value.theme = .mono
        value.floatOnTop = true
        try store.save(value)

        let loaded = store.load()
        XCTAssertEqual(loaded, value)
    }

    func testLoadReturnsDefaultOnCorruptData() {
        defaults.set(Data([0xFF, 0xFF]), forKey: SharedStore.storeKey)
        let store = SharedStore(defaults: defaults)
        XCTAssertEqual(store.load(), Store.defaultStore)
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
swift test --filter SharedStoreTests
```

Expected: compile failure — `SharedStore` undefined.

- [ ] **Step 3: Implement SharedStore**

Create `KeyWidgetShared/Sources/KeyWidgetShared/Persistence/SharedStore.swift`:
```swift
import Foundation

public final class SharedStore {
    public static let appGroupID = "group.com.williamappleton.keywidget"
    public static let storeKey = "com.williamappleton.keywidget.store"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public convenience init() {
        let suite = UserDefaults(suiteName: SharedStore.appGroupID) ?? .standard
        self.init(defaults: suite)
    }

    public func load() -> Store {
        guard let data = defaults.data(forKey: SharedStore.storeKey) else {
            return .defaultStore
        }
        return (try? JSONDecoder().decode(Store.self, from: data)) ?? .defaultStore
    }

    public func save(_ store: Store) throws {
        let data = try JSONEncoder().encode(store)
        defaults.set(data, forKey: SharedStore.storeKey)
    }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
swift test --filter SharedStoreTests
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add SharedStore for App Group persistence"
```

---

## Task 6: MarkdownRenderer — AST to HTML (TDD)

**Files:**
- Create: `KeyWidgetShared/Sources/KeyWidgetShared/Markdown/MarkdownRenderer.swift`
- Create: `KeyWidgetShared/Tests/KeyWidgetSharedTests/MarkdownRendererTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `KeyWidgetShared/Tests/KeyWidgetSharedTests/MarkdownRendererTests.swift`:
```swift
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
swift test --filter MarkdownRendererTests
```

Expected: compile failure — `MarkdownRenderer` undefined.

- [ ] **Step 3: Implement MarkdownRenderer**

Create `KeyWidgetShared/Sources/KeyWidgetShared/Markdown/MarkdownRenderer.swift`:
```swift
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
        escapeHTML(text.string)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(defaultVisit(emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(defaultVisit(strong))</strong>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<kbd>\(escapeHTML(inlineCode.code))</kbd>"
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
        ""
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br/>"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        " "
    }

    // MARK: - helpers

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
}
```

Notes on swift-markdown API quirks:
- `Image.plainText` returns the alt text (the children's text content). If your version of swift-markdown exposes it differently, use `defaultVisit(image)` stripped of tags. Verify the API signature when you run.
- Raw HTML (`HTMLBlock`, `InlineHTML`) is intentionally returned as empty strings to strip it.
- `Table.Cell` is a `Markup`; `defaultVisit` renders its children.

- [ ] **Step 4: Run tests and iterate**

```bash
swift test --filter MarkdownRendererTests
```

Expected: all pass. If any fail, adjust the visitor for the actual API shape (swift-markdown's exact types are on `main` branch and may have minor differences).

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add MarkdownRenderer (markdown AST → HTML)"
```

---

## Task 7: Plain-text preview extractor for the widget (TDD)

**Files:**
- Create: `KeyWidgetShared/Sources/KeyWidgetShared/Markdown/MarkdownPreview.swift`
- Create: `KeyWidgetShared/Tests/KeyWidgetSharedTests/MarkdownPreviewTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `KeyWidgetShared/Tests/KeyWidgetSharedTests/MarkdownPreviewTests.swift`:
```swift
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
```

- [ ] **Step 2: Run to confirm failure**

```bash
swift test --filter MarkdownPreviewTests
```

Expected: compile failure.

- [ ] **Step 3: Implement MarkdownPreview**

Create `KeyWidgetShared/Sources/KeyWidgetShared/Markdown/MarkdownPreview.swift`:
```swift
import Foundation
import Markdown

public enum MarkdownPreview {
    public static func extract(from markdown: String, maxLines: Int = 10) -> (title: String, preview: String) {
        let document = Document(parsing: markdown)
        var title: String?
        var previewParts: [String] = []

        for child in document.children {
            if title == nil, let heading = child as? Heading, heading.level == 1 {
                title = heading.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                continue
            }
            let text = (child as? Paragraph)?.plainText
                ?? (child as? Heading)?.plainText
                ?? ""
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
}
```

Note: `Markup.plainText` returns the concatenated text of all descendant text nodes, stripping markdown syntax. If the member isn't available in your swift-markdown version, walk the children recursively and accumulate `Text.string`.

- [ ] **Step 4: Run tests**

```bash
swift test --filter MarkdownPreviewTests
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add MarkdownPreview for widget title + preview extraction"
```

---

## Task 8: Write the bundled cheatsheet.md

**Files:**
- Create: `KeyWidgetApp/Resources/cheatsheet.md`

- [ ] **Step 1: Translate the HTML cheat sheet to markdown**

Read `/Users/will/src/KeyWidget/macos_keybinding_cheat_sheet.html` and translate its rows into a grouped markdown document. The HTML has 6 sections on the left (System, Finder, Windows & tabs) + 3 on the right (Editing, Text navigation, Browser) approximately — check each row when translating.

Create `KeyWidgetApp/Resources/cheatsheet.md`:
```markdown
# macOS Keybindings

## System

| Action | Shortcut |
|---|---|
| Spotlight search | `⌘` `Space` |
| Lock screen | `⌃` `⌘` `Q` |
| Sleep display | `⌃` `⇧` `⏏` |
| Force quit app | `⌥` `⌘` `Esc` |
| Screenshot (full) | `⌘` `⇧` `3` |
| Screenshot (selection) | `⌘` `⇧` `4` |
| Screenshot toolbar | `⌘` `⇧` `5` |
| Show/hide Dock | `⌥` `⌘` `D` |
| Mission Control | `⌃` `↑` |
| App Exposé | `⌃` `↓` |

## Finder

| Action | Shortcut |
|---|---|
| New Finder window | `⌘` `N` |
| New folder | `⌘` `⇧` `N` |
| Open selected item | `⌘` `O` |
| Get Info | `⌘` `I` |
| Quick Look | `Space` |
| Move to Trash | `⌘` `⌫` |
| Empty Trash | `⌘` `⇧` `⌫` |
| Show/hide hidden files | `⌘` `⇧` `.` |
| Go to folder | `⌘` `⇧` `G` |
| Go up a folder | `⌘` `↑` |

## Windows & tabs

| Action | Shortcut |
|---|---|
| New tab | `⌘` `T` |
| Close window/tab | `⌘` `W` |
| Quit app | `⌘` `Q` |
| Hide app | `⌘` `H` |
| Minimize window | `⌘` `M` |
| Cycle app windows | `` ⌘ ` `` |
| Switch apps | `⌘` `Tab` |
| Zoom window | `⌃` `⌘` `F` |
| Next tab | `⌃` `Tab` |
| Previous tab | `⌃` `⇧` `Tab` |

## Editing

| Action | Shortcut |
|---|---|
| Cut | `⌘` `X` |
| Copy | `⌘` `C` |
| Paste | `⌘` `V` |
| Paste and match style | `⌘` `⇧` `V` |
| Undo | `⌘` `Z` |
| Redo | `⌘` `⇧` `Z` |
| Select all | `⌘` `A` |
| Find | `⌘` `F` |
| Find & replace | `⌘` `⌥` `F` |
| Spell check | `⌘` `:` |

## Text navigation

| Action | Shortcut |
|---|---|
| Beginning of line | `⌘` `←` |
| End of line | `⌘` `→` |
| Top of document | `⌘` `↑` |
| Bottom of document | `⌘` `↓` |
| Word left / right | `⌥` `←` / `⌥` `→` |
| Select to line start | `⌘` `⇧` `←` |
| Select to line end | `⌘` `⇧` `→` |
| Select word | `⌥` `⇧` `←` / `→` |
| Delete word left | `⌥` `⌫` |
```

(Expand the remaining sections from the source HTML as needed — the translation is straightforward.)

- [ ] **Step 2: Add the file to the Xcode app target**

In Xcode: drag `cheatsheet.md` into the `KeyWidgetApp/Resources` group. Ensure "Copy items if needed" is unchecked (file is already in the folder), and **`KeyWidget` target** is checked in the "Add to targets" list.

- [ ] **Step 3: Verify the bundle contains the file**

In `AppDelegate.applicationDidFinishLaunching`, temporarily add:
```swift
if let url = Bundle.main.url(forResource: "cheatsheet", withExtension: "md") {
    print("cheatsheet at:", url.path)
} else {
    print("cheatsheet NOT bundled")
}
```

Run (⌘R). Expected: console prints the path. Remove the test print.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: add bundled macOS keybinding cheat sheet in markdown"
```

---

## Task 9: Theme CSS files and shared stylesheet

**Files:**
- Create: `KeyWidgetApp/Resources/Themes/shared.css`
- Create: `KeyWidgetApp/Resources/Themes/linear.css`
- Create: `KeyWidgetApp/Resources/Themes/iaWriter.css`
- Create: `KeyWidgetApp/Resources/Themes/mono.css`

- [ ] **Step 1: Write `shared.css`**

Create `KeyWidgetApp/Resources/Themes/shared.css`:
```css
:root {
    --bg: #ffffff;
    --fg: #111111;
    --fg-secondary: #555;
    --accent: #3478f6;
    --border: rgba(0,0,0,0.1);
    --kbd-bg: #f2f2f2;
    --kbd-fg: #222;
    --kbd-border: rgba(0,0,0,0.15);
    --font-sans: -apple-system, "SF Pro Text", system-ui, sans-serif;
    --font-mono: "SF Mono", "JetBrains Mono", Menlo, monospace;
    --font-serif: "Iowan Old Style", "Charter", "Palatino", Georgia, serif;
    --code-bg: rgba(0,0,0,0.04);
}

* { box-sizing: border-box; }

html, body {
    margin: 0;
    padding: 0;
    background: var(--bg);
    color: var(--fg);
    font-family: var(--font-sans);
    font-size: 14px;
    line-height: 1.6;
    -webkit-font-smoothing: antialiased;
}

body { padding: 28px 32px 40px; max-width: 820px; margin: 0 auto; }

h1 { font-size: 22px; font-weight: 600; letter-spacing: -0.01em; margin: 0 0 20px; }
h2 { font-size: 13px; font-weight: 500; color: var(--fg-secondary); text-transform: uppercase; letter-spacing: 0.08em; margin: 26px 0 8px; }
h3 { font-size: 15px; font-weight: 600; margin: 18px 0 6px; }

p { margin: 0 0 12px; }

a { color: var(--accent); text-decoration: none; border-bottom: 1px solid transparent; }
a:hover { border-bottom-color: var(--accent); }

kbd {
    display: inline-block;
    font-family: var(--font-mono);
    font-size: 11.5px;
    color: var(--kbd-fg);
    background: var(--kbd-bg);
    border: 0.5px solid var(--kbd-border);
    border-radius: 5px;
    padding: 1px 6px;
    line-height: 1.5;
    white-space: nowrap;
    margin: 0 1px;
}

table { width: 100%; border-collapse: collapse; border: 0.5px solid var(--border); border-radius: 10px; overflow: hidden; margin: 0 0 16px; }
th, td { text-align: left; padding: 8px 14px; border-bottom: 0.5px solid var(--border); font-size: 13px; }
thead { display: none; }
tr:last-child td { border-bottom: none; }
tbody td:first-child { color: var(--fg); }
tbody td:last-child { text-align: right; white-space: nowrap; }

ul, ol { margin: 0 0 14px; padding-left: 22px; }
li { margin: 2px 0; }

pre { background: var(--code-bg); border-radius: 8px; padding: 12px 14px; overflow-x: auto; font-family: var(--font-mono); font-size: 12.5px; line-height: 1.5; margin: 0 0 14px; }
blockquote { border-left: 3px solid var(--border); margin: 0 0 14px; padding: 2px 14px; color: var(--fg-secondary); }
hr { border: 0; border-top: 0.5px solid var(--border); margin: 20px 0; }

img { max-width: 100%; border-radius: 6px; }
```

Note: we hide `<thead>` and use `td` styling because the cheat sheet uses tables purely for action/shortcut layout. If you want visible column headers for other markdown docs, remove `thead { display: none; }` and add `th` styling.

- [ ] **Step 2: Write `iaWriter.css` (default theme)**

Create `KeyWidgetApp/Resources/Themes/iaWriter.css`:
```css
body.theme-iaWriter {
    --bg: #f7f3ec;
    --fg: #2b2721;
    --fg-secondary: #7b6d58;
    --accent: #b06b35;
    --border: #ddd2bd;
    --kbd-bg: transparent;
    --kbd-fg: #6b5d46;
    --kbd-border: transparent;
    --font-sans: "Iowan Old Style", "Charter", "Palatino", Georgia, serif;
    --font-mono: "SF Mono", "JetBrains Mono", Menlo, monospace;
    --code-bg: rgba(0,0,0,0.04);
}
body.theme-iaWriter h2 { font-style: italic; font-weight: 500; text-transform: none; letter-spacing: 0; color: var(--fg-secondary); font-family: -apple-system, system-ui, sans-serif; font-size: 12px; }
body.theme-iaWriter kbd { border: none; background: transparent; font-weight: 500; }
body.theme-iaWriter table { border: none; }
body.theme-iaWriter td { border-bottom-style: dotted; }
```

- [ ] **Step 3: Write `linear.css`**

Create `KeyWidgetApp/Resources/Themes/linear.css`:
```css
body.theme-linear {
    --bg: #0a0a0b;
    --fg: #e6e6ea;
    --fg-secondary: #7b7b86;
    --accent: #8b5cf6;
    --border: rgba(255,255,255,0.06);
    --kbd-bg: rgba(255,255,255,0.03);
    --kbd-fg: #e6e6ea;
    --kbd-border: rgba(255,255,255,0.1);
    --font-sans: -apple-system, "SF Pro Text", "Inter", system-ui, sans-serif;
    --code-bg: rgba(255,255,255,0.03);
}
body.theme-linear { background: radial-gradient(1200px 400px at 0% 0%, rgba(139,92,246,0.12), transparent 60%), #0a0a0b; }
body.theme-linear h2 { color: #7b7b86; letter-spacing: 0.1em; }
```

- [ ] **Step 4: Write `mono.css`**

Create `KeyWidgetApp/Resources/Themes/mono.css`:
```css
body.theme-mono {
    --bg: #0c0c0c;
    --fg: #d4d4c7;
    --fg-secondary: #7fc97f;
    --accent: #f4d35e;
    --border: #2a2a2a;
    --kbd-bg: transparent;
    --kbd-fg: #f4d35e;
    --kbd-border: transparent;
    --font-sans: "JetBrains Mono", "SF Mono", Menlo, monospace;
    --font-mono: "JetBrains Mono", "SF Mono", Menlo, monospace;
    --code-bg: #181818;
}
body.theme-mono kbd { border: none; background: transparent; padding: 0; }
body.theme-mono h2::before { content: "# "; color: #666; }
body.theme-mono table { border-radius: 0; }
body.theme-mono tr:not(:last-child) td { border-bottom-style: dashed; }
```

- [ ] **Step 5: Add the Themes folder to the app target**

In Xcode: drag `KeyWidgetApp/Resources/Themes/` into the project navigator. Ensure "Create folder references" is selected (so subdirectory structure is preserved in the bundle), and the `KeyWidget` target is checked.

- [ ] **Step 6: Verify the CSS is in the bundle**

Build (⌘B). Temporarily verify in `AppDelegate`:
```swift
if let url = Bundle.main.url(forResource: "shared", withExtension: "css", subdirectory: "Themes") {
    print("shared.css at:", url.path)
}
```
Run, remove the print.

- [ ] **Step 7: Commit**

```bash
git add .
git commit -m "feat: add shared and three theme CSS files"
```

---

## Task 10: MarkdownWebView — WKWebView host that renders a markdown string with a theme

**Files:**
- Create: `KeyWidgetApp/Markdown/MarkdownWebView.swift`
- Modify: `KeyWidgetApp/AppDelegate.swift` — set the window's contentView to an instance of MarkdownWebView loading the cheatsheet

- [ ] **Step 1: Implement MarkdownWebView**

Create `KeyWidgetApp/Markdown/MarkdownWebView.swift`:
```swift
import AppKit
import WebKit
import KeyWidgetShared

final class MarkdownWebView: NSView {
    let webView: WKWebView
    private let renderer = MarkdownRenderer()
    private var currentTheme: Theme = .iaWriter

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
        webView.setValue(false, forKey: "drawsBackground") // let CSS bg show through
    }

    required init?(coder: NSCoder) { fatalError() }

    func loadMarkdown(_ markdown: String, theme: Theme, baseURL: URL? = nil) {
        self.currentTheme = theme
        let body = renderer.render(markdown: markdown)
        let html = Self.wrap(body: body, theme: theme)
        webView.loadHTMLString(html, baseURL: baseURL ?? Bundle.main.resourceURL)
    }

    func apply(theme: Theme) {
        self.currentTheme = theme
        let js = """
        document.body.className = 'theme-\(theme.rawValue)';
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
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
        guard let url = Bundle.main.url(forResource: name, withExtension: "css", subdirectory: "Themes"),
              let css = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return css
    }
}
```

- [ ] **Step 2: Wire MarkdownWebView into AppDelegate**

Replace `KeyWidgetApp/AppDelegate.swift` with:
```swift
import AppKit
import KeyWidgetShared

final class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?
    var markdownView: MarkdownWebView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyWidget"
        window.center()

        let view = MarkdownWebView(frame: .zero)
        window.contentView = view
        self.markdownView = view

        loadBundledCheatsheet()

        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindow?.makeKeyAndOrderFront(nil) }
        return true
    }

    private func loadBundledCheatsheet() {
        guard let url = Bundle.main.url(forResource: "cheatsheet", withExtension: "md"),
              let md = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        markdownView?.loadMarkdown(md, theme: .iaWriter)
    }
}
```

- [ ] **Step 3: Build and run**

⌘R. Expected: the window now shows the rendered cheat sheet in the warm iA Writer theme, with styled tables, kbd-like keys, and section labels.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: render bundled cheatsheet in WKWebView with iA Writer theme"
```

---

## Task 11: Tab bar — display tabs from the shared store and switch between them

**Files:**
- Create: `KeyWidgetApp/MainWindow/TabBarView.swift`
- Create: `KeyWidgetApp/MainWindow/TabBarItemView.swift`
- Create: `KeyWidgetApp/MainWindow/MainContentViewController.swift`
- Modify: `KeyWidgetApp/AppDelegate.swift`

- [ ] **Step 1: Implement TabBarItemView**

Create `KeyWidgetApp/MainWindow/TabBarItemView.swift`:
```swift
import AppKit
import KeyWidgetShared

final class TabBarItemView: NSView {
    let tab: TabRef
    var isActive: Bool = false { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

    private let label = NSTextField(labelWithString: "")

    init(tab: TabRef) {
        self.tab = tab
        super.init(frame: .zero)
        label.stringValue = tab.displayTitle.isEmpty ? "Untitled" : tab.displayTitle
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isActive {
            let underline = NSRect(x: 10, y: 0, width: bounds.width - 20, height: 2)
            NSColor.controlAccentColor.setFill()
            underline.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override var intrinsicContentSize: NSSize {
        let labelSize = label.intrinsicContentSize
        return NSSize(width: labelSize.width + 24, height: 28)
    }

    func setActive(_ active: Bool) {
        isActive = active
        label.textColor = active ? .labelColor : .secondaryLabelColor
    }
}
```

- [ ] **Step 2: Implement TabBarView**

Create `KeyWidgetApp/MainWindow/TabBarView.swift`:
```swift
import AppKit
import KeyWidgetShared

final class TabBarView: NSView {
    var onSelect: ((UUID) -> Void)?

    private let scrollView = NSScrollView()
    private let stack = NSStackView()
    private var itemViews: [TabBarItemView] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: -1, height: 32) }

    func setTabs(_ tabs: [TabRef], activeID: UUID) {
        itemViews.forEach { $0.removeFromSuperview() }
        itemViews = tabs.map { tab in
            let item = TabBarItemView(tab: tab)
            item.setActive(tab.id == activeID)
            item.onClick = { [weak self] in self?.onSelect?(tab.id) }
            return item
        }
        itemViews.forEach { stack.addArrangedSubview($0) }
    }

    func updateActive(_ activeID: UUID) {
        itemViews.forEach { $0.setActive($0.tab.id == activeID) }
    }
}
```

- [ ] **Step 3: Implement MainContentViewController**

Create `KeyWidgetApp/MainWindow/MainContentViewController.swift`:
```swift
import AppKit
import KeyWidgetShared

final class MainContentViewController: NSViewController {
    private let store = SharedStore()
    private var state: Store = .defaultStore

    private let tabBar = TabBarView()
    private let markdownView = MarkdownWebView()
    private let divider = NSBox()

    override func loadView() {
        let container = NSView()
        view = container

        divider.boxType = .separator
        [tabBar, divider, markdownView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
        }

        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: container.topAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 32),
            divider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            divider.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            markdownView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            markdownView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            markdownView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            markdownView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        tabBar.onSelect = { [weak self] id in self?.selectTab(id) }
        reload()
    }

    private func reload() {
        state = store.load()
        tabBar.setTabs(visibleTabs(), activeID: state.activeTabID)
        loadActiveTabContent()
    }

    private func visibleTabs() -> [TabRef] {
        state.hideDefaultDoc
            ? state.tabs.filter { $0.kind != .bundled }
            : state.tabs
    }

    private func selectTab(_ id: UUID) {
        state.activeTabID = id
        try? store.save(state)
        tabBar.updateActive(id)
        loadActiveTabContent()
    }

    private func loadActiveTabContent() {
        guard let tab = state.tabs.first(where: { $0.id == state.activeTabID }) else { return }
        switch tab.kind {
        case .bundled:
            if let url = Bundle.main.url(forResource: "cheatsheet", withExtension: "md"),
               let md = try? String(contentsOf: url, encoding: .utf8) {
                markdownView.loadMarkdown(md, theme: state.theme)
            }
        case .userFile:
            // Will be implemented in Task 13 (security-scoped bookmark resolution)
            markdownView.loadMarkdown("Loading not yet implemented for user files.", theme: state.theme)
        }
    }
}
```

- [ ] **Step 4: Wire view controller into AppDelegate**

Replace the contents of `AppDelegate.applicationDidFinishLaunching`:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    let vc = MainContentViewController()
    let window = NSWindow(contentViewController: vc)
    window.setContentSize(NSSize(width: 720, height: 560))
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.title = "KeyWidget"
    window.center()
    window.makeKeyAndOrderFront(nil)
    self.mainWindow = window
}
```

Remove the now-unused `markdownView` and `loadBundledCheatsheet` properties/methods.

- [ ] **Step 5: Build and run**

⌘R. Expected: the window now shows a tab bar with one tab ("macOS Keybindings") selected, and the content below. Clicking the tab leaves it selected (we only have one tab).

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "feat: add tab bar driven by shared store"
```

---

## Task 12: Open a markdown file via ⌘O and add it as a tab

**Files:**
- Create: `KeyWidgetApp/Tabs/TabController.swift`
- Modify: `KeyWidgetApp/MainWindow/MainContentViewController.swift`
- Modify: `KeyWidgetApp/AppDelegate.swift`
- Modify: `KeyWidgetApp/Resources/MainMenu.xib` or add a menu programmatically

- [ ] **Step 1: Implement TabController**

Create `KeyWidgetApp/Tabs/TabController.swift`:
```swift
import AppKit
import KeyWidgetShared

final class TabController {
    private let store = SharedStore()

    func openFile(at url: URL) -> TabRef? {
        let absolute = url.resolvingSymlinksInPath().standardizedFileURL
        var state = store.load()

        if let existing = state.tabs.first(where: { tab in
            if let data = tab.bookmark,
               let resolved = resolveBookmark(data) {
                return resolved.resolvingSymlinksInPath().standardizedFileURL == absolute
            }
            return false
        }) {
            state.activeTabID = existing.id
            try? store.save(state)
            return existing
        }

        guard let bookmark = createBookmark(for: url) else { return nil }

        let title = (try? String(contentsOf: url, encoding: .utf8)).flatMap { md -> String? in
            let (t, _) = MarkdownPreview.extract(from: md)
            return t.isEmpty ? nil : t
        } ?? url.deletingPathExtension().lastPathComponent

        let new = TabRef(kind: .userFile, bookmark: bookmark, displayTitle: title)
        state.tabs.append(new)
        state.activeTabID = new.id
        try? store.save(state)
        return new
    }

    func createBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale { return nil }
        return url
    }

    func readContents(of tab: TabRef) -> String? {
        guard let data = tab.bookmark, let url = resolveBookmark(data) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
```

- [ ] **Step 2: Expose a "File → Open…" menu item**

In Xcode, open the app's main menu resource (generated in `MainMenu.xib` or similar). If the SwiftUI template doesn't include one, add a programmatic menu in `AppDelegate.applicationDidFinishLaunching` before creating the window:

```swift
NSApp.mainMenu = Self.buildMenu()
```

And add:
```swift
private static func buildMenu() -> NSMenu {
    let main = NSMenu()

    // App menu
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(NSMenuItem(title: "Preferences…", action: #selector(AppDelegate.showPreferences(_:)), keyEquivalent: ","))
    appMenu.addItem(.separator())
    appMenu.addItem(NSMenuItem(title: "Hide KeyWidget", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
    appMenu.addItem(NSMenuItem(title: "Quit KeyWidget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    appMenuItem.submenu = appMenu
    main.addItem(appMenuItem)

    // File menu
    let fileItem = NSMenuItem()
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(NSMenuItem(title: "Open…", action: #selector(AppDelegate.openFileMenu(_:)), keyEquivalent: "o"))
    let closeTab = NSMenuItem(title: "Close Tab", action: #selector(AppDelegate.closeTabMenu(_:)), keyEquivalent: "w")
    fileMenu.addItem(closeTab)
    let closeWin = NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    closeWin.keyEquivalentModifierMask = [.command, .shift]
    fileMenu.addItem(closeWin)
    fileItem.submenu = fileMenu
    main.addItem(fileItem)

    return main
}
```

Add to `AppDelegate`:
```swift
@objc func openFileMenu(_ sender: Any?) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [
        UTType(filenameExtension: "md")!,
        UTType(filenameExtension: "markdown")!,
        UTType(filenameExtension: "mdown")!,
        UTType(filenameExtension: "mdx")!,
    ]
    panel.allowsMultipleSelection = true
    panel.begin { [weak self] response in
        guard response == .OK else { return }
        for url in panel.urls {
            _ = self?.tabController.openFile(at: url)
        }
        NotificationCenter.default.post(name: .tabsDidChange, object: nil)
    }
}

@objc func closeTabMenu(_ sender: Any?) {
    NotificationCenter.default.post(name: .closeActiveTabRequested, object: nil)
}

@objc func showPreferences(_ sender: Any?) {
    // macOS 14+ selector for opening the SwiftUI Settings scene
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
}
```

Add the `import UniformTypeIdentifiers` at the top. Declare `let tabController = TabController()` as a property on `AppDelegate`.

Add notification names in a new file `KeyWidgetApp/Events/Notifications.swift`:
```swift
import Foundation
extension Notification.Name {
    static let tabsDidChange = Notification.Name("keywidget.tabsDidChange")
    static let closeActiveTabRequested = Notification.Name("keywidget.closeActiveTabRequested")
}
```

- [ ] **Step 3: React to tabsDidChange in MainContentViewController**

In `MainContentViewController`, add to `loadView()` (after `reload()`):
```swift
NotificationCenter.default.addObserver(
    self, selector: #selector(reload),
    name: .tabsDidChange, object: nil
)
```

Mark `reload` as `@objc`:
```swift
@objc private func reload() { ... }
```

Update the `.userFile` branch in `loadActiveTabContent` to use the tab controller:
```swift
case .userFile:
    let controller = (NSApp.delegate as? AppDelegate)?.tabController
    if let md = controller.flatMap({ $0.readContents(of: tab) }) {
        markdownView.loadMarkdown(md, theme: state.theme)
    } else {
        markdownView.loadMarkdown("# Couldn't find this file", theme: state.theme)
    }
```

- [ ] **Step 4: Build and run**

⌘R, then press ⌘O. Pick any `.md` file on your disk. Expected: a new tab appears in the bar, is selected, and its content renders.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add Open… menu item and user-file tabs"
```

---

## Task 13: Drag & drop markdown files onto the window

**Files:**
- Modify: `KeyWidgetApp/MainWindow/MainContentViewController.swift` — register drag types
- Add: drop handling on the main window's content view

- [ ] **Step 1: Add drop handling**

In `MainContentViewController.loadView()`, add after the constraints:
```swift
container.registerForDraggedTypes([.fileURL])
```

Subclass the container view into a drop-aware class. Instead of subclassing, implement the dragging delegate methods on the view controller. Since NSView forwards drag events to its own methods, the cleanest way is a custom NSView subclass.

Create a nested helper: change `let container = NSView()` to `let container = DropView()`, and add this class at the bottom of `MainContentViewController.swift`:

```swift
private final class DropView: NSView {
    var onDrop: (([URL]) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil) ? .copy : []
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        let mdURLs = urls.filter { ["md","markdown","mdown","mdx"].contains($0.pathExtension.lowercased()) }
        guard !mdURLs.isEmpty else { return false }
        onDrop?(mdURLs)
        return true
    }
}
```

In `loadView()`, after creating `container`:
```swift
container.onDrop = { [weak self] urls in
    guard let self else { return }
    let controller = (NSApp.delegate as? AppDelegate)?.tabController
    for url in urls { _ = controller?.openFile(at: url) }
    self.reload()
}
```

- [ ] **Step 2: Build and run**

⌘R. Drag a `.md` file from Finder onto the window. Expected: a new tab appears and its content loads.

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "feat: accept markdown files via drag and drop"
```

---

## Task 14: Close tabs — right-click menu, ⌘W, and drag-out with poof animation

**Files:**
- Modify: `KeyWidgetApp/MainWindow/TabBarItemView.swift` — context menu + drag
- Modify: `KeyWidgetApp/MainWindow/MainContentViewController.swift` — close handler
- Modify: `KeyWidgetApp/AppDelegate.swift` — forward ⌘W

- [ ] **Step 1: Close logic in TabController**

Add to `TabController`:
```swift
func closeTab(id: UUID) {
    var state = store.load()
    guard let idx = state.tabs.firstIndex(where: { $0.id == id }) else { return }
    let wasActive = state.activeTabID == id
    state.tabs.remove(at: idx)
    if wasActive, let fallback = state.tabs.first {
        state.activeTabID = fallback.id
    }
    try? store.save(state)
}

func canClose(_ tab: TabRef) -> Bool {
    tab.kind != .bundled
}
```

- [ ] **Step 2: Right-click menu on tab items**

In `TabBarItemView`, add:
```swift
var onClose: (() -> Void)?

override func menu(for event: NSEvent) -> NSMenu? {
    let menu = NSMenu()
    let item = NSMenuItem(title: "Close Tab", action: #selector(closeFromMenu), keyEquivalent: "")
    item.target = self
    menu.addItem(item)
    return menu
}

@objc private func closeFromMenu() { onClose?() }
```

In `TabBarView.setTabs`, wire `onClose`:
```swift
item.onClose = { [weak self] in self?.onClose?(tab.id) }
```

Add `var onClose: ((UUID) -> Void)?` to `TabBarView`.

In `MainContentViewController.loadView()`:
```swift
tabBar.onClose = { [weak self] id in self?.closeTab(id: id) }
NotificationCenter.default.addObserver(
    self, selector: #selector(closeActiveTab),
    name: .closeActiveTabRequested, object: nil
)
```

Add to `MainContentViewController`:
```swift
private func closeTab(id: UUID) {
    let controller = (NSApp.delegate as? AppDelegate)?.tabController
    guard let tab = state.tabs.first(where: { $0.id == id }),
          controller?.canClose(tab) == true else { return }
    controller?.closeTab(id: id)
    reload()
}

@objc private func closeActiveTab() {
    closeTab(id: state.activeTabID)
}
```

- [ ] **Step 3: Drag-out to close with poof**

In `TabBarItemView`:
```swift
override func mouseDragged(with event: NSEvent) {
    let pb = NSPasteboardItem()
    pb.setString(tab.id.uuidString, forType: .string)
    let item = NSDraggingItem(pasteboardWriter: pb)
    item.setDraggingFrame(bounds, contents: snapshot())
    let session = beginDraggingSession(with: [item], event: event, source: self)
    session.animatesToStartingPositionsOnCancelOrFail = false
}

private func snapshot() -> NSImage {
    let rep = bitmapImageRepForCachingDisplay(in: bounds)!
    cacheDisplay(in: bounds, to: rep)
    let image = NSImage(size: bounds.size)
    image.addRepresentation(rep)
    return image
}
```

Conform to `NSDraggingSource`:
```swift
extension TabBarItemView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .generic
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard let window = self.window else { return }
        let windowFrame = window.frame
        if !NSPointInRect(screenPoint, windowFrame) {
            NSAnimationEffect.poof.show(centeredAt: screenPoint, size: NSSize(width: 32, height: 32))
            onClose?()
        }
    }
}
```

Guard against closing the bundled tab — in the closure assignment within `TabBarView.setTabs`:
```swift
item.onClose = { [weak self] in
    guard let self, tab.kind != .bundled else { return }
    self.onClose?(tab.id)
}
```

- [ ] **Step 4: Build and run**

⌘R. Open a couple of markdown files. Verify:
- Right-click a user tab → Close Tab removes it.
- ⌘W with a user tab active closes it.
- Drag a user tab out of the window → puff animation + tab removed.
- The default cheat sheet tab cannot be closed by any mechanism.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: close tabs via menu, ⌘W, and drag-out with poof"
```

---

## Task 15: Reorder tabs by drag within the bar

**Files:**
- Modify: `KeyWidgetApp/MainWindow/TabBarView.swift` — accept drops from other tab items

- [ ] **Step 1: Register drag destination on stack / tab bar**

Approach: the simplest reliable reorder UX is click-and-drag horizontally with live reorder preview. For v1 we implement a simpler variant: detect a horizontal drag on a tab item that remains inside the tab bar, and on `draggingSession(_:endedAt:operation:)` check whether the end point is over another tab item; if so, reorder.

In `TabBarItemView.draggingSession(_:endedAt:operation:)`, extend:
```swift
func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    guard let window = self.window else { return }
    let windowPoint = window.convertPoint(fromScreen: screenPoint)
    let localPoint = self.superview?.superview?.convert(windowPoint, from: nil) ?? .zero
    let hostTabBar = self.enclosingTabBar()

    if let hostTabBar, hostTabBar.frame.contains(localPoint) {
        hostTabBar.reorderDidEnd(draggedTabID: tab.id, toPointInSelf: hostTabBar.convert(windowPoint, from: nil))
        return
    }
    if !NSPointInRect(screenPoint, window.frame) {
        NSAnimationEffect.poof.show(centeredAt: screenPoint, size: NSSize(width: 32, height: 32))
        onClose?()
    }
}

private func enclosingTabBar() -> TabBarView? {
    var v: NSView? = self
    while let cur = v { if let bar = cur as? TabBarView { return bar }; v = cur.superview }
    return nil
}
```

Add to `TabBarView`:
```swift
var onReorder: ((UUID, Int) -> Void)?

func reorderDidEnd(draggedTabID: UUID, toPointInSelf point: NSPoint) {
    let xs = itemViews.map { $0.frame.midX }
    let targetIndex = xs.firstIndex(where: { point.x < $0 }) ?? itemViews.count
    onReorder?(draggedTabID, targetIndex)
}
```

Add to `TabController`:
```swift
func moveTab(id: UUID, toIndex targetIndex: Int) {
    var state = store.load()
    guard let fromIndex = state.tabs.firstIndex(where: { $0.id == id }) else { return }
    let moved = state.tabs.remove(at: fromIndex)
    // Bundled tab must stay at index 0; clamp target accordingly
    let bundledAtZero = state.tabs.first?.kind == .bundled
    let clampedLow = bundledAtZero ? 1 : 0
    let clampedHigh = state.tabs.count
    let clamped = max(clampedLow, min(clampedHigh, targetIndex > fromIndex ? targetIndex - 1 : targetIndex))
    // Don't allow moving the bundled tab itself
    if moved.kind == .bundled {
        state.tabs.insert(moved, at: 0)
    } else {
        state.tabs.insert(moved, at: clamped)
    }
    try? store.save(state)
}
```

In `MainContentViewController.loadView()`:
```swift
tabBar.onReorder = { [weak self] id, idx in
    (NSApp.delegate as? AppDelegate)?.tabController.moveTab(id: id, toIndex: idx)
    self?.reload()
}
```

- [ ] **Step 2: Build and run**

⌘R. Open at least 3 user tabs. Drag one to a different horizontal position inside the tab bar. Verify the order updates after the drop. Drag the bundled tab — it should snap back.

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "feat: reorder tabs by drag within the tab bar"
```

---

## Task 16: Apply the active theme at runtime

**Files:**
- Modify: `KeyWidgetApp/MainWindow/MainContentViewController.swift` — call `markdownView.apply(theme:)` on theme change
- Modify: `KeyWidgetApp/AppDelegate.swift` — menu items for theme selection

- [ ] **Step 1: Add a View menu with Theme submenu**

In `AppDelegate.buildMenu()`, after the File menu, add:
```swift
let viewItem = NSMenuItem()
let viewMenu = NSMenu(title: "View")
let themeSubmenu = NSMenu(title: "Theme")
for theme in Theme.allCases {
    let mi = NSMenuItem(title: theme.displayName, action: #selector(AppDelegate.selectTheme(_:)), keyEquivalent: "")
    mi.representedObject = theme.rawValue
    themeSubmenu.addItem(mi)
}
let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
themeItem.submenu = themeSubmenu
viewMenu.addItem(themeItem)
viewItem.submenu = viewMenu
main.addItem(viewItem)
```

In `AppDelegate`:
```swift
@objc func selectTheme(_ sender: NSMenuItem) {
    guard let raw = sender.representedObject as? String, let theme = Theme(rawValue: raw) else { return }
    let store = SharedStore()
    var s = store.load()
    s.theme = theme
    try? store.save(s)
    NotificationCenter.default.post(name: .themeDidChange, object: nil)
}
```

Add `themeDidChange` to `Notifications.swift`.

- [ ] **Step 2: Observe in MainContentViewController**

```swift
NotificationCenter.default.addObserver(
    self, selector: #selector(themeChanged),
    name: .themeDidChange, object: nil
)
```

```swift
@objc private func themeChanged() {
    state = store.load()
    markdownView.apply(theme: state.theme)
}
```

- [ ] **Step 3: Build and run**

⌘R. View → Theme → Linear / iA Writer / Mono — verify the WebView restyles instantly without reloading.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: runtime theme switching via View menu"
```

---

## Task 17: File watching and auto-reload for user tabs

**Files:**
- Create: `KeyWidgetApp/FileWatching/FileWatcher.swift`
- Modify: `KeyWidgetApp/MainWindow/MainContentViewController.swift`

- [ ] **Step 1: Implement FileWatcher**

Create `KeyWidgetApp/FileWatching/FileWatcher.swift`:
```swift
import Foundation

final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private let url: URL
    private let onChange: () -> Void

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    func start() {
        stop()
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        self.fileDescriptor = fd
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        src.setEventHandler { [weak self] in self?.onChange() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        src.resume()
        self.source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit { stop() }
}
```

- [ ] **Step 2: Use FileWatcher from MainContentViewController**

Add properties:
```swift
private var watcher: FileWatcher?
```

Replace `loadActiveTabContent()` `.userFile` branch:
```swift
case .userFile:
    let controller = (NSApp.delegate as? AppDelegate)?.tabController
    guard let bookmark = tab.bookmark, let url = controller?.resolveBookmark(bookmark) else {
        markdownView.loadMarkdown("# Couldn't find this file", theme: state.theme)
        return
    }
    _ = url.startAccessingSecurityScopedResource()
    defer { url.stopAccessingSecurityScopedResource() }
    if let md = try? String(contentsOf: url, encoding: .utf8) {
        markdownView.loadMarkdown(md, theme: state.theme, baseURL: url.deletingLastPathComponent())
        startWatching(url)
    } else {
        markdownView.loadMarkdown("# Couldn't find this file", theme: state.theme)
    }
```

```swift
private func startWatching(_ url: URL) {
    watcher?.stop()
    watcher = FileWatcher(url: url) { [weak self] in
        // small debounce — rewrite-close-rename by editors is common
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self?.loadActiveTabContent()
        }
    }
    watcher?.start()
}

private func refreshTabTitle(from markdown: String, tabID: UUID) {
    let (title, _) = MarkdownPreview.extract(from: markdown)
    guard !title.isEmpty else { return }
    var s = store.load()
    guard let idx = s.tabs.firstIndex(where: { $0.id == tabID }),
          s.tabs[idx].displayTitle != title else { return }
    s.tabs[idx].displayTitle = title
    try? store.save(s)
    tabBar.setTabs(visibleTabs(), activeID: state.activeTabID)
    state = s
}
```

Where user-file content is successfully read (inside `loadActiveTabContent`'s success branch), call:
```swift
refreshTabTitle(from: md, tabID: tab.id)
```
so a changed H1 in the source file flows into the tab bar title and (via widget reload) the widget tile.

- [ ] **Step 3: Build and run**

⌘R. Open a markdown file. Edit it in another editor, save. Expected: content reloads within a fraction of a second.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: watch open files and auto-reload on external changes"
```

---

## Task 18: Missing-file state UI

**Files:**
- Create: `KeyWidgetApp/Tabs/MissingFileViewController.swift`
- Modify: `KeyWidgetApp/MainWindow/MainContentViewController.swift`

- [ ] **Step 1: Create MissingFileViewController**

Create `KeyWidgetApp/Tabs/MissingFileViewController.swift`:
```swift
import AppKit

final class MissingFileViewController: NSViewController {
    var pathHint: String = ""
    var onLocate: (() -> Void)?
    var onRemove: (() -> Void)?

    override func loadView() {
        let v = NSView()
        v.wantsLayer = true
        view = v

        let title = NSTextField(labelWithString: "Couldn't find this file")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "\(pathHint) — it may have moved or been deleted.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingMiddle

        let locate = NSButton(title: "Locate…", target: self, action: #selector(locate))
        let remove = NSButton(title: "Remove Tab", target: self, action: #selector(remove))

        let stack = NSStackView(views: [title, subtitle, NSStackView(views: [locate, remove])])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: v.widthAnchor, multiplier: 0.8),
        ])
    }

    @objc private func locate() { onLocate?() }
    @objc private func remove() { onRemove?() }
}
```

- [ ] **Step 2: Swap content view when file is missing**

In `MainContentViewController`, add:
```swift
private var missingVC: MissingFileViewController?
```

Replace the failure branch of the user-file load:
```swift
if let md = try? String(contentsOf: url, encoding: .utf8) {
    showMarkdown(md, baseURL: url.deletingLastPathComponent())
    startWatching(url)
} else {
    showMissing(path: url.path, tab: tab)
}
```

Add the helpers:
```swift
private func showMarkdown(_ md: String, baseURL: URL?) {
    missingVC?.view.removeFromSuperview()
    if markdownView.superview == nil { addMarkdownView() }
    markdownView.loadMarkdown(md, theme: state.theme, baseURL: baseURL)
}

private func showMissing(path: String, tab: TabRef) {
    markdownView.removeFromSuperview()
    let vc = MissingFileViewController()
    vc.pathHint = path
    vc.onLocate = { [weak self] in self?.relink(tab: tab) }
    vc.onRemove = { [weak self] in self?.closeTab(id: tab.id) }
    addChild(vc)
    vc.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(vc.view)
    NSLayoutConstraint.activate([
        vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        vc.view.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
        vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    missingVC = vc
}

private func addMarkdownView() {
    view.addSubview(markdownView)
    markdownView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        markdownView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        markdownView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        markdownView.topAnchor.constraint(equalTo: divider.bottomAnchor),
        markdownView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
}

private func relink(tab: TabRef) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [UTType(filenameExtension: "md")!]
    panel.begin { [weak self] response in
        guard response == .OK, let url = panel.url else { return }
        guard let controller = (NSApp.delegate as? AppDelegate)?.tabController,
              let bookmark = controller.createBookmark(for: url) else { return }
        var state = self?.store.load() ?? .defaultStore
        if let idx = state.tabs.firstIndex(where: { $0.id == tab.id }) {
            state.tabs[idx].bookmark = bookmark
            try? self?.store.save(state)
        }
        self?.reload()
    }
}
```

Note: import `UniformTypeIdentifiers` at the top.

- [ ] **Step 3: Build and run**

⌘R. Open a `.md` file. Then delete or rename the source file on disk. Expected: the content area shows the "Couldn't find this file" state with Locate… and Remove Tab buttons. Locate… → pick a new file → tab re-links. Remove Tab → tab disappears.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: handle missing file state with locate and remove actions"
```

---

## Task 19: Preferences window — theme, hide default doc, float on top

**Files:**
- Create: `KeyWidgetApp/Preferences/PreferencesView.swift`
- Modify: `KeyWidgetApp/App.swift` — wire the Settings scene

- [ ] **Step 1: Implement PreferencesView (SwiftUI)**

Create `KeyWidgetApp/Preferences/PreferencesView.swift`:
```swift
import SwiftUI
import KeyWidgetShared

struct PreferencesView: View {
    @State private var state: Store = SharedStore().load()
    private let store = SharedStore()

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $state.theme) {
                    ForEach(Theme.allCases, id: \.self) { t in
                        Text(t.displayName).tag(t)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: state.theme) { _, _ in save() }
            }

            Section("Behavior") {
                Toggle("Float on top", isOn: $state.floatOnTop)
                    .onChange(of: state.floatOnTop) { _, _ in save(postFloat: true) }
                Toggle("Hide the bundled cheat sheet tab", isOn: $state.hideDefaultDoc)
                    .onChange(of: state.hideDefaultDoc) { _, _ in save(postTabs: true) }
            }
        }
        .padding(20)
        .frame(width: 420, height: 280)
    }

    private func save(postFloat: Bool = false, postTabs: Bool = false) {
        try? store.save(state)
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
        if postFloat { NotificationCenter.default.post(name: .floatDidChange, object: nil) }
        if postTabs { NotificationCenter.default.post(name: .tabsDidChange, object: nil) }
    }
}
```

Add `floatDidChange` to `Notifications.swift`.

- [ ] **Step 2: Wire the Settings scene**

Replace `KeyWidgetApp/App.swift`:
```swift
import SwiftUI

@main
struct KeyWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { PreferencesView() }
    }
}
```

Verify the app's menu has a "Preferences…" item with ⌘, — the `Settings` scene auto-provides this; we previously added a placeholder in `buildMenu()`. Leave the menu entry; SwiftUI's Settings scene binds to the standard Preferences action.

- [ ] **Step 3: Build and run**

⌘R. ⌘, opens Preferences. Change theme → content re-themes. Toggle "Hide the bundled cheat sheet" → the cheat sheet tab disappears/reappears in the tab bar. Float-on-top toggle is wired but has no observer yet (Task 20).

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: preferences window with theme, hide-default, float-on-top"
```

---

## Task 20: Float-on-Top toggle with toolbar pin and window level

**Files:**
- Create: `KeyWidgetApp/MainWindow/FloatOnTopToolbar.swift`
- Modify: `KeyWidgetApp/AppDelegate.swift` — listen for `floatDidChange`, configure toolbar

- [ ] **Step 1: Add a toolbar with a pin item to the main window**

In `AppDelegate.applicationDidFinishLaunching`, after creating the window:
```swift
let toolbar = NSToolbar(identifier: "main")
toolbar.delegate = self
toolbar.displayMode = .iconOnly
toolbar.allowsUserCustomization = false
window.toolbar = toolbar
window.toolbarStyle = .unified
```

Make `AppDelegate` conform to `NSToolbarDelegate`:
```swift
extension AppDelegate: NSToolbarDelegate {
    static let floatItemID = NSToolbarItem.Identifier("floatOnTop")

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.floatItemID, .flexibleSpace]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.floatItemID]
    }
    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier == Self.floatItemID else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Float on Top"
        let button = NSButton(image: NSImage(systemSymbolName: "pin", accessibilityDescription: "Float on Top")!, target: self, action: #selector(toggleFloat))
        button.isBordered = false
        item.view = button
        return item
    }

    @objc func toggleFloat() {
        var s = SharedStore().load()
        s.floatOnTop = !s.floatOnTop
        try? SharedStore().save(s)
        applyFloatOnTop()
        NotificationCenter.default.post(name: .floatDidChange, object: nil)
    }

    func applyFloatOnTop() {
        let s = SharedStore().load()
        mainWindow?.level = s.floatOnTop ? .floating : .normal
        updatePinButtonImage(isPinned: s.floatOnTop)
    }

    private func updatePinButtonImage(isPinned: Bool) {
        let symbol = isPinned ? "pin.fill" : "pin"
        if let toolbar = mainWindow?.toolbar,
           let item = toolbar.items.first(where: { $0.itemIdentifier == Self.floatItemID }),
           let button = item.view as? NSButton {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
    }
}
```

In `applicationDidFinishLaunching`, after building the toolbar, call `applyFloatOnTop()`, and add:
```swift
NotificationCenter.default.addObserver(self, selector: #selector(floatChanged), name: .floatDidChange, object: nil)
```

```swift
@objc func floatChanged() { applyFloatOnTop() }
```

Add a View menu item:
```swift
let floatItem = NSMenuItem(title: "Float on Top", action: #selector(AppDelegate.toggleFloat), keyEquivalent: "f")
floatItem.keyEquivalentModifierMask = [.control, .option, .command]
viewMenu.insertItem(floatItem, at: 0)
```

- [ ] **Step 2: Build and run**

⌘R. Click the pin icon — window stays on top of other windows. Click again → back to normal. ⌃⌥⌘F toggles. Preferences toggle also works and is mirrored by the toolbar pin.

- [ ] **Step 3: Commit**

```bash
git add .
git commit -m "feat: float-on-top toolbar pin and menu item"
```

---

## Task 21: Deep link handling — keywidget:// URLs activate the app and focus the tab

**Files:**
- Create: `KeyWidgetApp/DeepLink/DeepLinkHandler.swift`
- Modify: `KeyWidgetApp/App.swift` — register `onOpenURL`
- Modify: `KeyWidgetApp/Info.plist` (already has URL scheme from Task 1)

- [ ] **Step 1: Implement DeepLinkHandler**

Create `KeyWidgetApp/DeepLink/DeepLinkHandler.swift`:
```swift
import AppKit
import KeyWidgetShared

enum DeepLinkHandler {
    static func handle(_ url: URL) {
        guard let link = DeepLink.parse(url) else { return }
        switch link {
        case .openApp:
            NSApp.activate(ignoringOtherApps: true)
            (NSApp.delegate as? AppDelegate)?.mainWindow?.makeKeyAndOrderFront(nil)
        case .openTab(let id):
            NSApp.activate(ignoringOtherApps: true)
            (NSApp.delegate as? AppDelegate)?.mainWindow?.makeKeyAndOrderFront(nil)
            var state = SharedStore().load()
            if state.tabs.contains(where: { $0.id == id }) {
                state.activeTabID = id
                try? SharedStore().save(state)
                NotificationCenter.default.post(name: .tabsDidChange, object: nil)
            }
        }
    }
}
```

- [ ] **Step 2: Wire `onOpenURL` in App.swift**

```swift
import SwiftUI

@main
struct KeyWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { PreferencesView() }
    }

    init() {
        NSAppleEventManager.shared().setEventHandler(
            AppURLHandler.shared,
            andSelector: #selector(AppURLHandler.handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
}

final class AppURLHandler: NSObject {
    static let shared = AppURLHandler()
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else { return }
        DeepLinkHandler.handle(url)
    }
}
```

- [ ] **Step 3: Test from terminal**

Run the app once so the URL scheme is registered with Launch Services, then in a shell:
```bash
open "keywidget://open?tab=$(uuidgen)"
```
Expected: app activates, focuses main window. With a valid tab id from your store, the tab is selected.

- [ ] **Step 4: Commit**

```bash
git add .
git commit -m "feat: handle keywidget:// deep links"
```

---

## Task 22: Widget extension — provider, entry, and themed views

**Files:**
- Create: `KeyWidgetWidget/` target (via Xcode)
- Create: `KeyWidgetWidget/Widget.swift`
- Create: `KeyWidgetWidget/Provider.swift`
- Create: `KeyWidgetWidget/Entry.swift`
- Create: `KeyWidgetWidget/EntryView.swift`

- [ ] **Step 1: Add the widget extension target**

In Xcode: File → New → Target → iOS + macOS → Widget Extension.
- Product Name: `KeyWidgetWidget`
- Include Configuration Intent: **unchecked**
- Embed in Application: KeyWidget

Xcode creates the widget target. Delete the generated template sources (we'll write our own).

In the widget target's Signing & Capabilities:
- Enable App Sandbox
- Enable App Groups → add `group.com.williamappleton.keywidget`

Link `KeyWidgetShared`:
- Widget target → General → Frameworks and Libraries → `+` → `KeyWidgetShared`.

Deployment: macOS 14.

- [ ] **Step 2: Implement Entry, Provider, and EntryView**

Create `KeyWidgetWidget/Entry.swift`:
```swift
import Foundation
import WidgetKit
import KeyWidgetShared

struct KeyWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let preview: String
    let theme: Theme
    let tabID: UUID
    let isMissing: Bool
    let isFirstLaunch: Bool
}
```

Create `KeyWidgetWidget/Provider.swift`:
```swift
import WidgetKit
import KeyWidgetShared

struct KeyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> KeyWidgetEntry {
        KeyWidgetEntry(
            date: .now,
            title: "macOS Keybindings",
            preview: "Spotlight search\n⌘ Space\nLock screen\n⌃ ⌘ Q",
            theme: .iaWriter,
            tabID: TabRef.bundledID,
            isMissing: false,
            isFirstLaunch: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (KeyWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<KeyWidgetEntry>) -> Void) {
        completion(Timeline(entries: [makeEntry()], policy: .never))
    }

    private func makeEntry() -> KeyWidgetEntry {
        let store = SharedStore().load()
        let tab = store.tabs.first { $0.id == store.activeTabID } ?? TabRef.bundled
        let isFirstLaunch = (store == .defaultStore && store.tabs.count == 1 && store.tabs[0].kind == .bundled)

        var title = tab.displayTitle
        var preview = ""
        var isMissing = false

        switch tab.kind {
        case .bundled:
            if let url = Bundle.main.url(forResource: "cheatsheet", withExtension: "md"),
               let md = try? String(contentsOf: url, encoding: .utf8) {
                let (t, p) = MarkdownPreview.extract(from: md, maxLines: 10)
                if !t.isEmpty { title = t }
                preview = p
            }
        case .userFile:
            if let md = readUserFile(tab: tab) {
                let (t, p) = MarkdownPreview.extract(from: md, maxLines: 10)
                if !t.isEmpty { title = t }
                preview = p
            } else {
                isMissing = true
            }
        }

        return KeyWidgetEntry(
            date: .now,
            title: title,
            preview: preview,
            theme: store.theme,
            tabID: tab.id,
            isMissing: isMissing,
            isFirstLaunch: isFirstLaunch
        )
    }

    private func readUserFile(tab: TabRef) -> String? {
        guard let data = tab.bookmark else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
```

Note: the widget target does NOT bundle `cheatsheet.md` by default. Either (a) also add `cheatsheet.md` to the widget target's Copy Bundle Resources (check it in the File Inspector's target membership), or (b) move `cheatsheet.md` into the `KeyWidgetShared` package with `resources: [.process("Resources")]` and read from `Bundle.module`. Option (a) is simpler for v1.

Create `KeyWidgetWidget/EntryView.swift`:
```swift
import SwiftUI
import WidgetKit
import KeyWidgetShared

struct KeyWidgetEntryView: View {
    let entry: KeyWidgetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        let palette = WidgetPalette.for(entry.theme)

        ZStack {
            palette.background.ignoresSafeArea()
            content
                .padding(family == .systemSmall ? 10 : 14)
                .foregroundStyle(palette.foreground)
        }
        .widgetURL(DeepLink.openTabURL(id: entry.tabID))
    }

    @ViewBuilder
    private var content: some View {
        if entry.isFirstLaunch {
            VStack(alignment: .leading, spacing: 4) {
                Text("Open KeyWidget").font(palette.titleFont).bold()
                Text("to get started").font(palette.bodyFont).opacity(0.7)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if entry.isMissing {
            VStack(alignment: .leading, spacing: 4) {
                Text("⚠︎ Couldn't find").font(palette.bodyFont).opacity(0.8)
                Text(entry.title).font(palette.titleFont).bold().lineLimit(2)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title).font(palette.titleFont).bold().lineLimit(2)
                if family != .systemSmall {
                    Text(entry.preview).font(palette.bodyFont).lineLimit(previewLineLimit)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var previewLineLimit: Int {
        switch family { case .systemMedium: return 3; default: return 10 }
    }

    private var palette: WidgetPalette { WidgetPalette.for(entry.theme) }
}

struct WidgetPalette {
    let background: Color
    let foreground: Color
    let titleFont: Font
    let bodyFont: Font

    static func `for`(_ theme: Theme) -> WidgetPalette {
        switch theme {
        case .iaWriter:
            return WidgetPalette(
                background: Color(red: 247/255, green: 243/255, blue: 236/255),
                foreground: Color(red: 43/255, green: 39/255, blue: 33/255),
                titleFont: .custom("Iowan Old Style", size: 15),
                bodyFont: .custom("Iowan Old Style", size: 11)
            )
        case .linear:
            return WidgetPalette(
                background: Color(red: 10/255, green: 10/255, blue: 11/255),
                foreground: Color(red: 230/255, green: 230/255, blue: 234/255),
                titleFont: .system(size: 14, weight: .semibold),
                bodyFont: .system(size: 11, weight: .regular)
            )
        case .mono:
            return WidgetPalette(
                background: Color(red: 12/255, green: 12/255, blue: 12/255),
                foreground: Color(red: 212/255, green: 212/255, blue: 199/255),
                titleFont: .system(.body, design: .monospaced).weight(.semibold),
                bodyFont: .system(.caption, design: .monospaced)
            )
        }
    }
}
```

Create `KeyWidgetWidget/Widget.swift`:
```swift
import SwiftUI
import WidgetKit

@main
struct KeyWidgetWidget: Widget {
    let kind: String = "KeyWidgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KeyWidgetProvider()) { entry in
            KeyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("KeyWidget")
        .description("Your currently active cheat sheet, glanceable on the desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
```

- [ ] **Step 3: Trigger widget reloads from the app**

In the app, whenever the active tab, file content, or theme changes, reload timelines. Create `KeyWidgetApp/Widget/WidgetReloader.swift`:
```swift
import WidgetKit

enum WidgetReloader {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

Call `WidgetReloader.reload()` from:
- `MainContentViewController.selectTab` (after save)
- `MainContentViewController.reload` at the end
- `MainContentViewController.themeChanged` after save
- `MainContentViewController.loadActiveTabContent` when it successfully reads a file (for preview refresh)

- [ ] **Step 4: Build and run**

⌘R the app once. Then from the macOS Desktop, right-click → Edit Widgets (or drag the widget from the gallery) — add KeyWidget. Expected: widget shows the active tab's title and preview in the selected theme. Switch active tabs or theme in the app; the widget updates within a few seconds. Tap the widget → app activates and focuses the tab.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: add WidgetKit widget that mirrors active tab"
```

---

## Task 23: Empty state, hover states, small polish

**Files:**
- Create: `KeyWidgetApp/MainWindow/EmptyStateView.swift`
- Modify: `KeyWidgetApp/MainWindow/MainContentViewController.swift`
- Modify: `KeyWidgetApp/MainWindow/TabBarItemView.swift` — hover background

- [ ] **Step 1: Empty state view**

Create `KeyWidgetApp/MainWindow/EmptyStateView.swift`:
```swift
import AppKit

final class EmptyStateView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let label = NSTextField(labelWithString: "Drop a markdown file here, or press ⌘O.")
        label.textColor = .tertiaryLabelColor
        label.font = .systemFont(ofSize: 13, weight: .regular)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}
```

- [ ] **Step 2: Show empty state when there are no visible tabs**

In `MainContentViewController.reload()`:
```swift
if visibleTabs().isEmpty {
    markdownView.removeFromSuperview()
    missingVC?.view.removeFromSuperview()
    showEmptyState()
} else {
    emptyView?.removeFromSuperview()
    // existing logic
}
```

Add:
```swift
private var emptyView: EmptyStateView?

private func showEmptyState() {
    let v = EmptyStateView()
    emptyView = v
    v.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(v)
    NSLayoutConstraint.activate([
        v.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        v.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        v.topAnchor.constraint(equalTo: divider.bottomAnchor),
        v.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
}
```

- [ ] **Step 3: Tab hover highlight**

In `TabBarItemView.init`, add tracking area:
```swift
let tracking = NSTrackingArea(
    rect: .zero,
    options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
    owner: self, userInfo: nil
)
addTrackingArea(tracking)
wantsLayer = true
```

```swift
override func mouseEntered(with event: NSEvent) {
    layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor
}
override func mouseExited(with event: NSEvent) {
    layer?.backgroundColor = nil
}
```

- [ ] **Step 4: Build and run**

⌘R. Verify:
- Enable "Hide default doc" in Preferences, then close all user tabs → empty-state text appears; drop a file onto the window → tab opens.
- Hover over user tabs → subtle background; leave → clears.

- [ ] **Step 5: Commit**

```bash
git add .
git commit -m "feat: empty state and tab hover polish"
```

---

## Task 24: README.md in the project voice

**Files:**
- Create: `README.md` at repo root

- [ ] **Step 1: Write the README**

Create `/Users/will/src/KeyWidget/README.md`:
```markdown
# KeyWidget

A reference card for your desktop. Read markdown where you're already working.

> KeyWidget keeps a stack of your most-referenced markdown files one click away — a bundled macOS keybinding cheat sheet by default, and whatever else you drop on it. The app floats on top when you want it to, gets out of the way when you don't, and reads your files from disk so your editor stays the source of truth.

<!-- Replace with real screenshots once the app builds -->
![Linear theme](docs/screenshots/linear.png)
![iA Writer theme](docs/screenshots/iaWriter.png)
![Mono theme](docs/screenshots/mono.png)

## Getting started

Requires macOS 14 and Xcode 15+.

```
open KeyWidget.xcodeproj
```

Press ⌘R.

## Philosophy

Reference-first, not editing. You already have a favorite editor — KeyWidget doesn't try to be it. Drop a markdown file on the window and it becomes a tab that stays in sync with your file on disk. No import, no copies, no conflict.

The app does one thing well: show you the right cheat sheet at the right time, in a form that's pleasant to look at.

## Themes

Three themes ship by default. Pick one from *View → Theme* or ⌘, to open Preferences.

- **Linear** — dark canvas, sharp sans-serif, a whisper of gradient.
- **iA Writer** — warm paper, serif body, dotted dividers. Default.
- **Mono** — monospace everywhere, brutalist, hacker-y.

## License

See [LICENSE](LICENSE).
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add project README"
```

---

## Final verification

- [ ] Run all shared-package tests:
  ```bash
  cd /Users/will/src/KeyWidget/KeyWidgetShared
  swift test
  ```
  Expected: all tests pass.

- [ ] Build the Xcode workspace:
  ```bash
  cd /Users/will/src/KeyWidget
  xcodebuild -project KeyWidget.xcodeproj -scheme KeyWidget -destination 'platform=macOS' build
  ```
  Expected: BUILD SUCCEEDED.

- [ ] Smoke test in Xcode (⌘R):
  - App launches, cheat sheet renders in iA Writer theme.
  - Theme switch (View menu) changes appearance instantly.
  - ⌘O opens a markdown file as a new tab.
  - Drag a markdown file onto the window → new tab.
  - Right-click a user tab → Close Tab.
  - ⌘W closes the active user tab (not the bundled one).
  - Drag a user tab out of the window → puff + removed.
  - Reorder tabs by drag.
  - Edit an open markdown file externally, save → tab content auto-refreshes.
  - Delete the file → missing-file UI appears.
  - Pin icon toggles float-on-top.
  - Preferences (⌘,) shows theme picker, hide-default-doc, float-on-top.
  - Hide default doc → cheat sheet tab disappears; unhide → reappears.
  - Add the widget from the widget gallery; it shows the active tab's title and preview.
  - Tap widget → app activates and focuses the tab.

- [ ] Commit any final fixes from smoke testing.
