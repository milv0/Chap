# Chap - Codex Agent Instructions

Follow these instructions when working in this repository.

## Project Snapshot

Chap is a macOS 14+ menu bar launcher written in Swift, AppKit, and SwiftUI. It
launches URLs, macOS apps, and Finder folders (up to four URLs or folders
and six apps), then centers resizable windows on the selected display.

Alongside the always-present status menu it offers an optional Notch Launcher (a
six-slot panel that expands from the MacBook notch, with Chap Drop and a
Screenshot Shelf), Keep Mac Awake sessions, and Sparkle update checks.

This is an XcodeGen project:

```bash
xcodegen generate
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" build
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
```

There is no `Package.swift`; do not use `swift test`. Releases are cut locally
with `Scripts/release.sh` (see "Release flow" below).

## Structure

- `project.yml`: XcodeGen source of truth.
- `Chap.xcodeproj/`: generated Xcode project.
- `Scripts/`: release, notarization, appcast, and DMG/PKG build scripts.
- `docs/`: GitHub Pages website (`index.html`) and the signed `appcast.xml`.
- `Sources/ChapCore/`: models, validation, policies (notch/drop/screenshot/keep-awake),
  settings view model, logging.
- `Sources/Chap/AppDelegate.swift`: status item, site launching, managed windows.
  Split across `AppDelegate+Config.swift` (config migration/load/strip),
  `AppDelegate+Lifecycle.swift` (launch/terminate, windows, login item), and
  `AppDelegate+Menu.swift` (menu build, hotkeys, status icon, Keep Awake events).
- `Sources/Chap/NotchLauncherController.swift`: notch hotzone/panel/badge orchestration.
- `Sources/Chap/ChapDrop.swift`, `ScreenshotShelf.swift`, `ThumbnailLoader.swift`:
  Chap Drop store, Screenshot Shelf source, and async thumbnails.
- `Sources/Chap/KeepAwakeController.swift`, `KeepAwakeHUD.swift`: Keep Mac Awake session and HUD.
- `Sources/Chap/UpdateController.swift`: Sparkle updater (fail-closed).
- `Sources/Chap/Launchers/`: Chrome, app, Finder launchers.
- `Sources/Chap/Views/`: SwiftUI UI (settings, notch panel/settings, QA, onboarding).
- `Tests/ChapCoreTests/`: Swift Testing tests.
- `.harness/shared/rules/`: shared rules for assistants.
- `ARCHITECTURE.txt`: structure, features, APIs, change history.
- `FLOW.md`: runtime flow — startup order, permission state machine, per-launcher
  sequences with timeouts, thread map, invariants, known issues.
- `NOTCH.md`: notch surface geometry spec. `DESIGN.md`: color tokens.

## Behavior

Global shortcuts:

- `Option + .`: open the menu bar menu.
- `Option + custom key`: launch the matching site.
- `Option + ,`: open Settings.
- `Option + Shift + T`: copy text from a dragged screen area (ScreenCaptureKit +
  Vision, in memory only; needs Screen Recording permission).

Launch types:

- `url`: Chrome `--app` mode via `/usr/bin/open`; AX API detects and resizes the
  new Chrome window. Optional reuse remembers only the window ID created by that
  launchable for the current Chap/Chrome session; never search user tabs or use a
  focused/frontmost window fallback.
- `app`: `NSWorkspace.openApplication`; AXObserver plus polling fallback resizes
  standard windows, and resizable non-standard Office windows.
- `finder`: Finder AppleScript opens the folder and sets bounds atomically.

Config lives at `~/.chap.json`; backup path is `~/.chap.json.bak`.

The Shell launch type was removed in 2.1. Config decoding drops legacy `shell`
sites and the `scripts` notch widget; the original file is backed up once to
`~/.chap.json.shell-scripts.bak`. Never reintroduce arbitrary command execution.

Other surfaces:

- Notch Launcher (optional, off by default): `NotchLauncherController` shows a
  `.nonactivatingPanel` under the hardware notch that expands on hover and holds
  six slots (Sites, Apps, Finder, or Screenshots; Mirror, Quick Note, and Copy Text from Screen are icons in the black top strip beside the Drop badge). It is additive —
  the status-bar menu is always available, including on notchless Macs. Chap Drop
  copies dropped files into `~/Library/Application Support/Chap/Drop/` (originals
  untouched); the Screenshot Shelf reads the system screenshot folder in place.
  Notch geometry lives in `ChapCore/NotchGeometry.swift` (see `NOTCH.md`).
- Keep Mac Awake: `KeepAwakeController` holds an IOKit assertion for a
  `KeepAwakePolicy` preset (30m–12h). Expiry is wall-clock based via a
  `DispatchSourceTimer` with `wallDeadline`, re-checked on system/screen wake and
  when the status menu opens; a session that expired during sleep ends quietly.
  State is in memory only, never persisted.
- Updates: `UpdateController` wraps Sparkle fail-closed — it starts only with a
  valid `SUFeedURL` and `SUPublicEDKey`, and never during tests.

## Release flow

Daily work stays on `dev`; commit and push only that branch. Releases are cut
locally with `Scripts/release.sh <version>` (read-only until `--publish`).
`--publish` bumps version metadata, validates, promotes `dev` → `main`, tags,
builds/notarizes the signed PKG and DMG, publishes the GitHub Release, and
verifies the Pages appcast. Do not bump version numbers by hand — the release
script owns `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`.

## Rules

Follow these files before making relevant changes:

- `.harness/shared/rules/swift-conventions.md`
- `.harness/shared/rules/swift-testing.md`
- `.harness/shared/rules/commit-convention.md`
- `.harness/shared/rules/architecture-docs.md`

Important expectations:

- Read `FLOW.md` before changing launch, resize, permission, or shortcut behavior.
  Its invariants section lists past regressions; check it before altering window
  targeting, timeouts, or the Chrome serial queue.
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
