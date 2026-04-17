# Next Steps

Session notes for picking this project back up. Current state: build 22, drag-drop / zoom / widget tap / preferences all working, theme backgrounds fill the whole window, README has screenshots.

See also: [gotchas.md](gotchas.md) for hard-won technical notes.

## Quick wins

- **Strip diagnostic logs.** We left `os.Logger` calls all over — in `AppDelegate`, `DeepLinkHandler`, `TabController`, `MainContentViewController`, `MarkdownWebView`, `DropAwareWebView`. Useful while debugging, noisy in Console now that everything works. Safe to trim down to errors only.
- **Bump `CFBundleVersion` in `project.yml`** on each meaningful commit. The window title shows it (`KeyWidget v0.1.0 · build N`). Keep the habit — it's how we tell if a rebuild actually picked up.

## Features worth considering

- **Restore user-file tabs on launch.** State persists in SharedStore, but re-opening security-scoped bookmarked files at startup hasn't been verified end-to-end. If it works, great — if not, needs a `startAccessingSecurityScopedResource()` pass during app launch for each stored `TabRef.bookmark`.
- **Find in document (⌘F).** WKWebView has a built-in find UI; just need a menu item + key equivalent that calls `webView.find(...)`.
- **Finish the bundled cheatsheet.** Only 5 of the 6-ish sections from `macos_keybinding_cheat_sheet.html` were translated. The "Browser" section is still missing.
- **Launch at login.** Deferred from the v1 spec. `SMAppService.mainApp` is a small addition if we want it.
- **Widget tap verification after any AppDelegate change** — confirmed working in build 21, but it's historically fragile; worth a smoke test whenever URL-handling code changes.

## Design polish

- **Real app icon.** Current `⌘` on warm paper is serviceable programmer-art. `scripts/gen-icon.swift` is the generator if we want to iterate programmatically; or drop a hand-drawn 1024×1024 in and regenerate sizes.
- **Float-on-top pin feedback.** Toolbar pin swaps `pin`/`pin.fill` SF Symbols but could pulse briefly on toggle for tactile confirmation.

## Cleanup lying around

- `macos_keybinding_cheat_sheet.html` — the source HTML we translated into the bundled markdown. Currently committed; either leave it as historical reference or delete.
- `keywidget_testlog.txt` — gitignored. Used for capturing `log stream` output during debugging. Safe to delete locally.
