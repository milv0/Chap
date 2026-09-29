# Chap - Kiro Project Steering

Chap is a macOS 14+ menu bar launcher written in Swift, AppKit, and SwiftUI. It
uses XcodeGen (`project.yml`) to generate `Chap.xcodeproj`. It launches URLs,
macOS apps, and Finder folders (up to four URLs or folders and six apps)
and centers resizable windows on the selected display. Alongside the status menu
it offers an optional Notch Launcher (a six-slot panel with Chap Drop and a
Screenshot Shelf), Keep Mac Awake sessions, and Sparkle update checks.

## Commands

```bash
xcodegen generate
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" build
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
xcrun swift-format lint Sources Tests
```

There is no `Package.swift`; do not use `swift test`.

## Structure

- `Sources/ChapCore/`: testable models, validation, policies (notch/drop/screenshot/keep-awake),
  settings view model, logging.
- `Sources/Chap/AppDelegate.swift`: status item, site launching, managed windows.
  Split into `AppDelegate+Config.swift` (config I/O), `AppDelegate+Lifecycle.swift`
  (lifecycle, windows, login item), and `AppDelegate+Menu.swift` (menu, hotkeys,
  status icon, Keep Awake events).
- `Sources/Chap/NotchLauncherController.swift`: notch hotzone/panel/badge orchestration.
- `Sources/Chap/ChapDrop.swift`, `ScreenshotShelf.swift`, `ThumbnailLoader.swift`:
  Chap Drop store, Screenshot Shelf source, async thumbnails.
- `Sources/Chap/KeepAwakeController.swift`, `KeepAwakeHUD.swift`: Keep Mac Awake session and HUD.
- `Sources/Chap/UpdateController.swift`: Sparkle updater (fail-closed).
- `Sources/Chap/Launchers/`: Chrome, app, Finder launch behavior.
- `Sources/Chap/Views/`: SwiftUI settings, site config, notch panel/settings, QA, welcome, components.
- `Tests/ChapCoreTests/`: Swift Testing unit tests for `ChapCore`.
- `Scripts/`: release, notarization, appcast, DMG/PKG build scripts.
- `docs/`: GitHub Pages website (`index.html`) and the signed `appcast.xml`.
- `.harness/shared/rules/`: shared assistant rules.
- `ARCHITECTURE.txt`: structure, features, APIs, change history.
- `FLOW.md`: runtime flow — startup order, permission state machine, per-launcher
  sequences with timeouts, thread map, invariants, known issues.
- `NOTCH.md`: notch surface geometry spec. `DESIGN.md`: color tokens.

## Behavior

- `Option + .`: open menu.
- `Option + custom key`: launch the matching site.
- `Option + ,`: open Settings.
- URL launch uses Chrome `--app` plus AX API resize. Optional reuse remembers
  only the window ID created by that launchable for the current Chap/Chrome
  session; it never searches user tabs or uses focused/frontmost fallbacks.
- App launch uses `NSWorkspace.openApplication` plus AXObserver/polling resize, including resizable non-standard Office windows.
- Finder launch uses AppleScript to open and set bounds atomically.
- Notch Launcher (optional, off by default): `NotchLauncherController` shows a
  `.nonactivatingPanel` under the hardware notch with six slots (Sites, Apps,
  Finder, Screenshots, or Downloads; Mirror and Quick Note are icons in the black top strip beside the Drop badge); the status menu stays available, including
  on notchless Macs. Chap Drop copies dropped files into
  `~/Library/Application Support/Chap/Drop/` (originals untouched); the Screenshot
  Shelf reads the system screenshot folder in place.
- Keep Mac Awake: `KeepAwakeController` holds an IOKit assertion for a
  `KeepAwakePolicy` preset (30m–12h), expiring on a wall-clock `DispatchSourceTimer`
  re-checked on wake and when the menu opens; a session expired during sleep ends
  quietly. State is memory only.
- Updates: `UpdateController` wraps Sparkle fail-closed — it starts only with a
  valid `SUFeedURL` and `SUPublicEDKey`, and never during tests.
- Config lives at `~/.chap.json`; backup path is `~/.chap.json.bak`.
- The Shell launch type was removed in 2.1. Config decoding drops legacy `shell`
  sites and the `scripts` notch widget; the original is backed up once to
  `~/.chap.json.shell-scripts.bak`. Never reintroduce arbitrary command execution.

## Release flow

Daily work stays on `dev`; commit and push only that branch. Releases are cut
locally with `Scripts/release.sh <version>` (read-only until `--publish`).
`--publish` bumps version metadata, validates, promotes `dev` → `main`, tags,
builds/notarizes the signed PKG and DMG, and publishes the GitHub Release. Do not
bump version numbers by hand — the release script owns
`MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`.

## Rules

- Read `FLOW.md` before changing launch, resize, permission, or shortcut behavior;
  its invariants section lists past regressions.
- Follow `.harness/shared/rules/swift-conventions.md`.
- Follow `.harness/shared/rules/swift-testing.md` for tests.
- Follow `.harness/shared/rules/architecture-docs.md`; update `ARCHITECTURE.txt`
  when files, shortcuts, launch behavior, permissions, or config shape change.
- Keep commits conventional and attribution-free per
  `.harness/shared/rules/commit-convention.md`.
