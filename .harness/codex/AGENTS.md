# Chap - Codex Agent Instructions

Follow these instructions when working in this repository.

## Project Snapshot

Chap is a macOS 14+ menu bar launcher written in Swift, AppKit, and SwiftUI. It
launches URLs, macOS apps, Finder folders, and shell scripts, then centers
resizable windows on the selected display.

This is an XcodeGen project:

```bash
xcodegen generate
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" build
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
```

There is no `Package.swift`; do not use `swift test`.

## Structure

- `project.yml`: XcodeGen source of truth.
- `Chap.xcodeproj/`: generated Xcode project.
- `Sources/ChapCore/`: models, validation, settings view model, logging.
- `Sources/Chap/AppDelegate.swift`: app lifecycle, menu, config I/O, global shortcuts.
- `Sources/Chap/Launchers/`: Chrome, app, Finder, shell launchers.
- `Sources/Chap/Views/`: SwiftUI UI.
- `Tests/ChapCoreTests/`: Swift Testing tests.
- `.harness/shared/rules/`: shared rules for assistants.

## Behavior

Global shortcuts:

- `Option + .`: open the menu bar menu.
- `Option + custom key`: launch the matching site.
- `Option + ,`: open Settings.

Launch types:

- `url`: Chrome `--app` mode via `/usr/bin/open`; AX API detects and resizes the
  new Chrome window.
- `app`: `NSWorkspace.openApplication`; AXObserver plus polling fallback resizes
  standard windows.
- `finder`: Finder AppleScript opens the folder and sets bounds atomically.
- `shell`: runs the configured script through `$SHELL -c`; no resize.

Config lives at `~/.chap.json`; backup path is `~/.chap.json.bak`.

## Rules

Follow these files before making relevant changes:

- `.harness/shared/rules/swift-conventions.md`
- `.harness/shared/rules/swift-testing.md`
- `.harness/shared/rules/commit-convention.md`
- `.harness/shared/rules/architecture-docs.md`

Important expectations:

- Keep changes scoped to the correct area: `ChapCore` for testable logic,
  `Launchers` for launch behavior, `Views` for UI, `AppDelegate` for app
  lifecycle/menu/window orchestration.
- Update `ARCHITECTURE.txt` when files, shortcuts, launch behavior, permissions,
  or config shape change.
- Prefer tests for `ChapCore` model, validation, migration, and view-model logic.
- Do not push unless the user explicitly asks.
- Do not add AI attribution or `Co-Authored-By` lines to commits.

## Validation

Run the narrowest useful check. For Swift changes, prefer:

```bash
xcrun swift-format lint Sources Tests
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
```

`xcodebuild` writes under Xcode DerivedData. If sandboxing blocks it, request
permission to rerun the same command outside the sandbox.
