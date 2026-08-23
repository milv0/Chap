# Chap - Kiro Project Steering

Chap is a macOS 14+ menu bar launcher written in Swift, AppKit, and SwiftUI. It
uses XcodeGen (`project.yml`) to generate `Chap.xcodeproj`.

## Commands

```bash
xcodegen generate
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" build
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
xcrun swift-format lint Sources Tests
```

There is no `Package.swift`; do not use `swift test`.

## Structure

- `Sources/ChapCore/`: testable models, validation, settings view model, logging.
- `Sources/Chap/AppDelegate.swift`: app lifecycle, menu, config I/O, global shortcuts.
- `Sources/Chap/Launchers/`: Chrome, app, Finder, shell launch behavior.
- `Sources/Chap/Views/`: SwiftUI settings, site config, QA, welcome, components.
- `Tests/ChapCoreTests/`: Swift Testing unit tests for `ChapCore`.
- `.harness/shared/rules/`: shared assistant rules.
- `ARCHITECTURE.txt`: structure, features, APIs, change history.
- `FLOW.md`: runtime flow — startup order, permission state machine, per-launcher
  sequences with timeouts, thread map, invariants, known issues.

## Behavior

- `Option + .`: open menu.
- `Option + custom key`: launch the matching site.
- `Option + ,`: open Settings.
- URL launch uses Chrome `--app` plus AX API resize. Optional reuse remembers
  only the window ID created by that launchable for the current Chap/Chrome
  session; it never searches user tabs or uses focused/frontmost fallbacks.
- App launch uses `NSWorkspace.openApplication` plus AXObserver/polling resize, including resizable non-standard Office windows.
- Finder launch uses AppleScript to open and set bounds atomically.
- Shell launch runs the configured script through `$SHELL -c`.

## Rules

- Read `FLOW.md` before changing launch, resize, permission, or shortcut behavior;
  its invariants section lists past regressions.
- Follow `.harness/shared/rules/swift-conventions.md`.
- Follow `.harness/shared/rules/swift-testing.md` for tests.
- Follow `.harness/shared/rules/architecture-docs.md`; update `ARCHITECTURE.txt`
  when files, shortcuts, launch behavior, permissions, or config shape change.
- Keep commits conventional and attribution-free per
  `.harness/shared/rules/commit-convention.md`.
