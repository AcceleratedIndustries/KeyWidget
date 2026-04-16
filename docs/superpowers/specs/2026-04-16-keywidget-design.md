# KeyWidget — Design Spec

**Date:** 2026-04-16
**Status:** Draft for implementation

## Summary

KeyWidget is a macOS app plus a WidgetKit desktop widget for quickly referencing keyboard shortcut cheat sheets and other short markdown reference documents. It ships with a bundled macOS keybinding cheat sheet as the default tab, and lets the user add any markdown files from disk as additional tabs. The widget is a glanceable desktop tile that reflects whichever tab is currently active in the app; tapping it launches the app and focuses that tab. The app supports three hand-designed themes, a "float on top" mode for cramming muscle memory, and auto-reloads tabs when their source files change on disk.

## Goals and non-goals

**Goals**
- A beautiful, low-friction way to keep a keyboard cheat sheet visible while working.
- Support for adding arbitrary markdown files as tabs without importing or copying content.
- Three distinct themes (one warm light, two dark) so the app looks great in any mood.
- A companion desktop widget that mirrors the active tab and deep-links back into the app.

**Non-goals (v1)**
- Markdown editing inside the app (it's a viewer — users edit in their own editor).
- Cloud sync, iCloud, cross-device state.
- Search, export, print, share.
- iOS or iPadOS targets.
- Multiple app windows.
- User-created custom themes beyond the three presets.

## System architecture

Three pieces in one Xcode project:

1. **KeyWidget.app** — the main macOS app. Hosts the tabbed window, preferences, and the WKWebView-based markdown viewer.
2. **KeyWidgetWidget** — the WidgetKit extension. Renders a small desktop tile that mirrors the active tab.
3. **KeyWidgetShared** — a Swift package linked by both targets. Contains data models, the shared store, deep-link parsing, and anything else both processes need to agree on.

**State ownership:** the app is the single writer of all state. The widget reads the shared store and renders. There is no path where the widget writes state.

**Widget refresh:** the app calls `WidgetCenter.shared.reloadAllTimelines()` whenever (a) the active tab changes, (b) a tab's file changes on disk, or (c) the theme changes. The widget does not run its own periodic timeline — its content is purely derived from app state.

**Deep linking:** the widget is a single tappable surface. Tap → `keywidget://open?tab=<id>` → app launches or activates and focuses the referenced tab.

## App window and UI shell

**Main window**
- Single main window. Follows standard macOS conventions: closing the window hides it (the app stays running in the Dock), ⌘Q quits. Clicking the Dock icon when no windows are visible reopens the main window (`applicationShouldHandleReopen`).
- Default size on first launch: 720×560 px. Resizable. Minimum 480×360 px.
- Last-used size and position are restored on launch.
- Standard traffic-light controls. No custom title bar — native feel.
- `NSWindow.level` toggles between `.normal` and `.floating` via the Float-on-Top control.

**Toolbar (NSToolbar)**
- Left: nothing — the tab bar sits in its own row below the toolbar.
- Right: pin icon (Float-on-Top toggle, shows current state), and a "…" more-menu with Preferences, Theme submenu, Hide Default Doc toggle.

**Menu bar**
- **File:** Open… (⌘O), Close Tab (⌘W), Close Window (⌘⇧W), Locate Missing File…
- **View:** Float on Top (⌃⌥⌘F), Theme › {Linear, iA Writer, Mono}, Hide Default Doc
- **Window** / **Help:** standard

**Preferences window** (⌘,)
- Theme picker with three radio buttons and mini previews
- "Hide the bundled cheat sheet tab" toggle
- "Float on top" toggle (mirrors the toolbar pin)
- "Launch at login" toggle (via `SMAppService`)

**Empty state**
- If the user has hidden the default doc and has no other tabs, the window shows a centered drop zone: *"Drop a markdown file here, or press ⌘O."*

## Tab model

**Default tab**
- A bundled markdown file `cheatsheet.md` (a rewrite of the existing `macos_keybinding_cheat_sheet.html`).
- Pinned leftmost. Non-draggable, non-closeable.
- Can be hidden entirely via a preference toggle.

**User tabs**
- Each tab is a reference to a file on disk — we store a **security-scoped bookmark**, not the content.
- Adding:
  - ⌘O → `NSOpenPanel` filtered to `.md`, `.markdown`, `.mdown`, `.mdx`.
  - Drag-and-drop one or more `.md` files anywhere on the window. Each becomes a tab. Last dropped tab becomes active.
  - Deduplication: if a file is already open (by canonical resolved path), adding it again activates the existing tab rather than creating a duplicate.
- Closing: three equivalent mechanisms, all non-destructive (never touch the file on disk):
  - Drag a tab out of the window → puff-of-smoke animation, tab removed.
  - ⌘W on the active tab.
  - Right-click → Close Tab.
- Reordering: drag within the tab bar. The default cheat sheet stays pinned leftmost (unless hidden).
- Overflow: tab row scrolls horizontally when there are too many tabs to fit. No overflow menu.

**Tab titles**
- H1 of the document if present, else the filename without extension.
- Titles re-compute when a tab's file is reloaded.

**Active tab indicator**
- 2px underline in the theme's accent color.

**Missing file state**
- When a tab's file cannot be read (moved, renamed, deleted — we can't distinguish), the tab stays in place with a dimmed/italicized title, and the content area shows:
  > **Couldn't find this file**
  > `<stored path>` — it may have moved or been deleted.
  >
  > [Locate…]   [Remove tab]
- **Locate…** opens `NSOpenPanel` so the user can re-link to the moved file. Updates the stored bookmark, keeps tab position.
- **Remove tab** explicitly removes the tab reference.
- Drag-out and ⌘W also work on missing-file tabs.

## Markdown rendering pipeline

**Steps**
1. Read markdown text — from the bundled asset (`cheatsheet.md`) for the default tab, or via the security-scoped bookmark for user tabs.
2. Parse with **`swift-markdown`** (Apple's official library) into an AST.
3. Render AST → HTML string using a small custom renderer that we own. The renderer maps:
   - Inline code → `<kbd>` elements (so the cheat-sheet key-chip look is automatic for any `` `⌘` `` in any doc).
   - Fenced code blocks → `<pre><code>` with a `language-*` class if specified (no syntax highlighting in v1 — the CSS just styles the block).
   - Everything else → standard semantic HTML.
   - Raw embedded HTML is **stripped** (we never inject untrusted HTML into our WebView).
4. Inject the HTML into a `WKWebView`. Each tab owns a persistent `WKWebView` instance so scroll position and WebView state survive tab switches. Tab switch = swap which WebView is visible in the content area.
5. A single shared stylesheet is injected at load. CSS custom properties (`--bg`, `--fg`, `--accent`, `--kbd-bg`, `--kbd-fg`, `--border`, `--font-sans`, `--font-mono`, `--font-serif`) are set on `<html>` based on the active theme. Theme switch is instant — just swap the variable values.

**Supported markdown features**
- Headings, paragraphs, emphasis/strong, blockquotes, horizontal rules
- Ordered and unordered lists
- Links (open in the user's default browser, not in the WebView)
- Inline code (rendered as `<kbd>`)
- Fenced code blocks
- GFM tables
- GFM task lists
- Images: local paths (resolved relative to the markdown file's directory) and `https://` URLs. The WKWebView loads them with its default loader.

**Not supported in v1**
- Raw embedded HTML (stripped)
- MathJax, Mermaid, custom extensions
- Syntax highlighting for code blocks (beyond CSS styling of the block itself)

## Themes

Three themes ship in v1. All use the same markup; only CSS differs.

**A. Linear** — dark near-black canvas, subtle radial gradient, sharp sans-serif, hairline borders, gradient accent on the active tab underline.

**B. iA Writer** (default) — warm paper background (`#f7f3ec`), serif body, dotted dividers, italic section labels. Low contrast, calming.

**C. Mono** — `#0c0c0c` background, monospace everywhere (JetBrains Mono / SF Mono), tab titles rendered as filenames (e.g., `macos-keys.md`), green/yellow accents, sparse visual chrome.

**Theme storage**: `theme: "linear" | "iaWriter" | "mono"`. Default on first launch: `iaWriter`. Changeable from Preferences or View → Theme.

**Theme swap behavior**: instantaneous. No WebView reload. Only CSS custom properties change.

## Widget behavior

**Content**
- Active tab's title (H1 or filename).
- A short plain-text preview: the first 3-5 lines of rendered content, stripped of formatting.
- Theme-matched styling (three SwiftUI views, one per theme).

**Sizes supported**
- Small (square) — title + small icon.
- Medium (wide) — title + 3-line preview.
- Large — title + ~10 lines of preview.
- Extra-large is not supported.

**Timeline**
- Purely event-driven. No periodic refresh.
- App triggers `WidgetCenter.shared.reloadAllTimelines()` on: active tab change, file change in the active tab, theme change.

**Tap**
- The whole widget is one tap target. Tap → `keywidget://open?tab=<id>` → app launches or activates and focuses that tab.

**Edge cases**
- Active tab's file is missing → widget shows "⚠︎ Couldn't find *filename*". Tap launches the app to the missing-file UI.
- App has never been opened → widget shows "Open KeyWidget to get started". Tap launches the app to the bundled cheat sheet.

## Persistence and shared storage

All persistent state lives in an **App Group** `UserDefaults` suite (e.g., `group.com.yourname.keywidget`), accessible from both the app and the widget.

**Schema**
```swift
struct Store: Codable {
    var tabs: [TabRef]              // ordered list, leftmost first
    var activeTabID: UUID
    var theme: Theme                // .linear | .iaWriter | .mono
    var floatOnTop: Bool
    var hideDefaultDoc: Bool
    var windowFrame: CGRect
}

struct TabRef: Codable, Identifiable {
    let id: UUID
    var bookmark: Data?             // security-scoped bookmark; nil for the bundled default tab
    var displayTitle: String        // cached H1 or filename (for widget; refreshed on reload)
    var kind: TabKind               // .bundled | .userFile
}
```

**Bundled default tab** — represented by a sentinel `TabRef` with `kind == .bundled` and `bookmark == nil`. Its content is always read from the app bundle.

**Bookmarks** — user tabs store a security-scoped bookmark generated at the time the user picked or dropped the file. On app launch, bookmarks are resolved with `.withSecurityScope`; stale bookmarks trigger the missing-file UI.

## File watching and auto-reload

- Each open user tab watches its resolved file with `DispatchSource.makeFileSystemObjectSource` on `.write`, `.rename`, `.delete`.
- On `.write`: re-read + re-render within ~200ms. Scroll position preserved.
- On `.rename` or `.delete`: move the tab to the missing-file state.
- Watchers are created when a tab becomes resident in memory and torn down when the app quits.

## Technical stack

- **Language:** Swift 6
- **UI:** SwiftUI for widget, preferences, and theme pickers; AppKit for the main window, tab bar, and WKWebView hosting.
- **Minimum macOS:** 14 (Sonoma) — required for desktop widgets.
- **Dependencies (Swift Package Manager):**
  - `swift-markdown` (Apple)
  - Nothing else.
- **Sandboxing & entitlements:**
  - App sandbox: on
  - `com.apple.security.files.user-selected.read-only`
  - `com.apple.security.files.bookmarks.app-scope`
  - App Group: `group.com.yourname.keywidget`
  - URL scheme: `keywidget`
- **Build/run:** standard Xcode build. No CI in v1.

## Project layout

```
KeyWidget.xcodeproj
├── KeyWidgetApp/                 (macOS app target)
│   ├── App.swift
│   ├── MainWindow.swift
│   ├── TabBar.swift              (custom NSView-backed tab bar with drag-out support)
│   ├── MarkdownView.swift        (WKWebView host + pipeline)
│   ├── MarkdownRenderer.swift    (swift-markdown AST → HTML)
│   ├── Themes/                   (Linear.css, iAWriter.css, Mono.css, shared.css)
│   ├── Preferences.swift
│   ├── FileWatcher.swift
│   ├── DeepLinkHandler.swift
│   └── Resources/cheatsheet.md   (bundled default, rewritten from the original HTML)
├── KeyWidgetWidget/              (WidgetKit extension target)
│   ├── Widget.swift
│   ├── WidgetEntryView.swift
│   └── ThemedPreview.swift
└── KeyWidgetShared/              (Swift package, linked by both)
    ├── Sources/KeyWidgetShared/
    │   ├── Models.swift          (TabRef, Store, Theme enum)
    │   ├── SharedStore.swift     (App Group UserDefaults accessor)
    │   └── DeepLink.swift
    └── Tests/KeyWidgetSharedTests/
        ├── ModelsTests.swift
        ├── DeepLinkTests.swift
        └── RendererTests.swift   (markdown → HTML snapshots)
```

## Testing

**Unit tests** (in `KeyWidgetSharedTests`):
- Markdown → HTML rendering: golden-output tests for each significant feature (headings, inline code → kbd, tables, task lists, images, link escaping).
- Tab model invariants: dedupe by canonical path, reorder preserves identity, default tab cannot be removed or reordered.
- Deep link parsing: valid URLs, malformed URLs, missing tab IDs.

**Manual visual verification** — run the app and eyeball the three themes against the agreed-upon mockups. UI automation is out of scope for v1.

## Implementation sequencing (suggested)

Rough dependency order — actual plan will come from the `writing-plans` step that follows:

1. `KeyWidgetShared` package: models, store, deep link parsing, with unit tests.
2. Main app scaffolding: app lifecycle, main window, empty tab bar, deep-link handling.
3. Markdown rendering pipeline: AST → HTML, WKWebView host, one theme (iA Writer) only.
4. Tab lifecycle: open from file picker, drag-and-drop, persistence, reorder, drag-out-to-close.
5. File watching and auto-reload.
6. Remaining two themes (Linear, Mono) and the theme picker.
7. Preferences window, Float-on-Top, hide-default-doc.
8. Widget extension: read shared store, render tile, deep link back.
9. Missing-file UI and edge cases.
10. Rewrite the original `macos_keybinding_cheat_sheet.html` as `cheatsheet.md` and bundle it.
11. Polish pass: empty state, hover states, animations, puff-of-smoke.

## Deferred decisions

These aren't design gaps — they're naming/deployment details to settle during implementation setup:

- **App bundle ID and App Group ID.** Placeholder `group.com.yourname.keywidget` is used throughout. Needs a final identifier once the developer account / team ID is known.
- **App icon.** Not designed yet. Placeholder for v1.

## Open questions

None at time of writing. If any surface during implementation, raise them before coding around them.
