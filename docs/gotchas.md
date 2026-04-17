# Gotchas

Hard-won notes — things that broke during v0.1 development and how to keep them fixed.

## AppDelegate identity

- **`NSApp.delegate as? AppDelegate` is unreliable** with `@NSApplicationDelegateAdaptor` — use `AppDelegate.shared` instead. Every current call site already does.
- **`NSApp.mainMenu` gets replaced** when SwiftUI's `Settings` scene activates. We re-install our custom menu on `didBecomeKey`/`didResignKey`. If we ever add more scenes, extend that observer.

## Widget extension

- **Widget extension + hardened runtime** requires `ENABLE_DEBUG_DYLIB: NO` in `project.yml` on the widget target — otherwise the widget process can't load the split dylib and renders the generic "Please adopt containerBackground" placeholder.

## WKWebView in a sandboxed app

Requires all of:

- `loadFileURL` (not `loadHTMLString` with a file:// baseURL)
- `com.apple.security.cs.allow-jit`
- `com.apple.security.cs.allow-unsigned-executable-memory`
- `com.apple.security.network.client`

Already wired up — don't regress.

## Drag-and-drop

- **Drag-drop from Finder** requires reading the pasteboard with `.urlReadingFileURLsOnly: true` to preserve the sandbox extension for `bookmarkData(.withSecurityScope)`.
- WKWebView re-registers its own drag types on every navigation — the only reliable way to intercept drops on the web view is to override the NSDraggingDestination methods on a WKWebView subclass (see `DropAwareWebView`).

## Theme background

- The theme class goes on `<html>`, not `<body>`. CSS variables cascade down, not up — putting the theme class on body leaves `<html>` stuck with the `:root` default, which shows as white bars around the centered max-width body.

## LaunchServices — widget routing debugging

Multiple copies of `KeyWidget.app` registered under the same bundle ID cause widget taps to route to stale processes. Cleanup:

```bash
pkill -x KeyWidget
# find stale registrations:
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -dump \
  | grep -B1 -A4 'com.williamappleton.keywidget' | head -40
# remove one:
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u <path-to-stale.app>
```
