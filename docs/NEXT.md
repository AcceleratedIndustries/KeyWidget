# Next Steps

Session notes for picking this project back up. Current state: build 21, drag-drop / zoom / widget tap / preferences all working.

## Quick wins

- **Strip diagnostic logs.** We left `os.Logger` calls all over — in `AppDelegate`, `DeepLinkHandler`, `TabController`, `MainContentViewController`, `MarkdownWebView`, `DropAwareWebView`. Useful while debugging, noisy in Console now that everything works. Safe to trim down to errors only.
- **Bump `CFBundleVersion` in `project.yml`** on each meaningful commit. The window title shows it (`KeyWidget v0.1.0 · build N`). Keep the habit — it's how we tell if a rebuild actually picked up.
- **README screenshots.** Placeholder comment still in `README.md`. With the app rendering properly, capture one shot per theme (Linear, iA Writer, Mono) into `docs/screenshots/` and un-comment the image links.

## Features worth considering

- **Restore user-file tabs on launch.** State persists in SharedStore, but re-opening security-scoped bookmarked files at startup hasn't been verified end-to-end. If it works, great — if not, needs a `startAccessingSecurityScopedResource()` pass during app launch for each stored `TabRef.bookmark`.
- **Find in document (⌘F).** WKWebView has a built-in find UI; just need a menu item + key equivalent that calls `webView.find(...)`.
- **Finish the bundled cheatsheet.** Only 5 of the 6-ish sections from `macos_keybinding_cheat_sheet.html` were translated. The "Browser" section is still missing.
- **Launch at login.** Deferred from the v1 spec. `SMAppService.mainApp` is a small addition if we want it.
- **Widget tap verification after any AppDelegate change** — confirmed working in build 21, but it's historically fragile; worth a smoke test whenever URL-handling code changes.

## Design polish

- **Real app icon.** Current `⌘` on warm paper is serviceable programmer-art. `scripts/gen-icon.swift` is the generator if we want to iterate programmatically; or drop a hand-drawn 1024×1024 in and regenerate sizes.
- **Float-on-top pin feedback.** Toolbar pin swaps `pin`/`pin.fill` SF Symbols but could pulse briefly on toggle for tactile confirmation.

## Gotchas to remember

- **`NSApp.delegate as? AppDelegate` is unreliable** with `@NSApplicationDelegateAdaptor` — use `AppDelegate.shared` instead. Every current call site already does.
- **`NSApp.mainMenu` gets replaced** when SwiftUI's `Settings` scene activates. We re-install our custom menu on `didBecomeKey`/`didResignKey`. If we ever add more scenes, extend that observer.
- **Widget extension + hardened runtime** requires `ENABLE_DEBUG_DYLIB: NO` in `project.yml` on the widget target — otherwise the widget process can't load the split dylib and renders the generic "Please adopt containerBackground" placeholder.
- **WKWebView in a sandboxed app** needs:
  - `loadFileURL` (not `loadHTMLString` with a file:// baseURL)
  - `com.apple.security.cs.allow-jit`
  - `com.apple.security.cs.allow-unsigned-executable-memory`
  - `com.apple.security.network.client`
  
  Already wired up — don't regress.
- **Drag-drop from Finder** requires reading the pasteboard with `.urlReadingFileURLsOnly: true` to preserve the sandbox extension for `bookmarkData(.withSecurityScope)`.

## Cleanup lying around

- `macos_keybinding_cheat_sheet.html` — the source HTML we translated into the bundled markdown. Currently committed; either leave it as historical reference or delete.
- `keywidget_testlog.txt` — gitignored. Used for capturing `log stream` output during debugging. Safe to delete locally.

## If you're LaunchServices-debugging widget routing again

Multiple copies of `KeyWidget.app` registered under the same bundle ID cause widget taps to route to stale processes. Cleanup:

```bash
pkill -x KeyWidget
# find stale registrations:
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump \
  | grep -B1 -A4 'com.williamappleton.keywidget' | head -40
# remove one:
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u <path-to-stale.app>
```
