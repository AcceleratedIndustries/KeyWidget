# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-17

Initial release.

### Added

- Tabbed markdown viewer with three built-in themes: **Linear** (dark),
  **iA Writer** (warm paper, default), and **Mono** (brutalist monospace).
- Bundled macOS keybindings cheat sheet as the default tab.
- Drop any `.md` / `.markdown` / `.mdown` / `.mdx` file on the window to add a
  tab. ⌘O opens a file picker for the same.
- Security-scoped bookmarks persist user-file tabs across launches. Missing
  files show a "Locate…" recovery view.
- File watching: edits in your external editor reload live.
- Desktop widget that mirrors the currently active tab's title and body
  preview. Tap the widget to bring the matching tab forward.
- Float-on-top toggle: toolbar pin + ⌃⌥⌘F + Preferences checkbox.
- Find in document (⌘F) with live search, next/previous navigation, and
  no-match feedback.
- Zoom controls: ⌘= / ⌘- / ⌘0.
- Preferences window (⌘,) for theme, float-on-top, hide-default-doc, and
  launch-at-login.
- Launch at login via `SMAppService.mainApp` — no extra entitlements.

### Known limitations

- Drag-to-close a tab closes the tab but shows no visual effect. The old
  `NSAnimationEffect.poof` was deprecated in macOS 14; Apple's suggested
  replacement doesn't apply here.
