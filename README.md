# KeyWidget

A reference card for your desktop. Read markdown where you're already working.

> KeyWidget keeps a stack of your most-referenced markdown files one click away — a bundled macOS keybinding cheat sheet by default, and whatever else you drop on it. The app floats on top when you want it to, gets out of the way when you don't, and reads your files from disk so your editor stays the source of truth.

<!-- Screenshots to be added once the app has shippable UI. Bundled cheat sheet, each theme. -->

## Getting started

Requires macOS 14, Xcode 15+, and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```
brew install xcodegen
./bin/gen
open KeyWidget.xcodeproj
```

Press ⌘R.

The Xcode project is generated from `project.yml` and is gitignored. Run `./bin/gen` whenever you change `project.yml` or add a new target.

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
