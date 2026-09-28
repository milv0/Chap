# Chap - Claude Code Project Instructions

This file is loaded by Claude Code for this repository. Keep it aligned with
`README.md`, `ARCHITECTURE.txt`, and the shared rules under `.harness/shared/rules/`.

## Project Snapshot

Chap is a macOS 14+ menu bar launcher written in Swift, AppKit, and SwiftUI. It
launches URLs, macOS apps, Finder folders, and shell scripts (up to four items
per launch type), then centers resizable windows on the selected display.

Beyond the always-present status menu it also offers an optional Notch Launcher
(a four-slot panel that expands from the MacBook notch, with Chap Drop and a
Screenshot Shelf), Keep Mac Awake sessions, and Sparkle-based update checks.

The project is XcodeGen-based:

```bash
xcodegen generate
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" build
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
```

There is no `Package.swift`; use Xcode or `xcodebuild`, not `swift test`.
Releases are cut locally with `Scripts/release.sh` (see "Release flow" below),
not a checked-in GitHub Actions workflow.

## Repository Structure

```text
Chap/
├── .harness/                         # AI assistant harness
│   ├── shared/rules/                 # Shared rules for Claude, Kiro, Codex
│   ├── shared/hooks/swift-format.sh  # Swift format/lint hook
│   ├── claude/                       # Claude Code settings and commands
│   ├── kiro/                         # Kiro hooks and steering
│   └── codex/                        # Codex AGENTS.md source
├── .claude -> .harness/claude
├── .kiro -> .harness/kiro
├── AGENTS.md -> .harness/codex/AGENTS.md
├── project.yml                       # XcodeGen project definition
├── Chap.xcodeproj/                   # Generated Xcode project
├── Scripts/                          # Release, notarize, appcast, DMG/PKG build
├── docs/                             # GitHub Pages website (index.html) + appcast.xml
├── Sources/
│   ├── Chap/                         # App target
│   │   ├── main.swift                # NSApplication entry point
│   │   ├── AppDelegate.swift         # Status item, site launching, managed windows
│   │   ├── AppDelegate+Config.swift  # Config migration, load, legacy-field strip
│   │   ├── AppDelegate+Lifecycle.swift # Launch/terminate, windows, login item
│   │   ├── AppDelegate+Menu.swift    # Menu build, hotkeys, status icon, Keep Awake
│   │   ├── NotchLauncherController.swift # Notch hotzone/panel/badge orchestration
│   │   ├── ChapDrop.swift            # Chap Drop store (~/Library/Application Support/Chap/Drop/)
│   │   ├── ScreenshotShelf.swift     # Reads the system screenshot folder
│   │   ├── ThumbnailLoader.swift     # Async thumbnails for Drop/Screenshot rows
│   │   ├── KeepAwakeController.swift  # IOKit Keep Mac Awake session (wall-clock timer)
│   │   ├── KeepAwakeHUD.swift        # Keep Awake start/stop HUD
│   │   ├── UpdateController.swift    # Sparkle updater (fail-closed)
│   │   ├── Launchers/                # URL/App/Finder/Shell launch behavior
│   │   └── Views/                    # SwiftUI settings, notch, QA, onboarding UI
│   └── ChapCore/                     # Models, validation, policies, view model, logging
├── Tests/ChapCoreTests/              # Swift Testing unit tests
├── Resources/                        # App and status bar icons
├── assets/icons/                     # Source SVG icon assets
├── ARCHITECTURE.txt                  # Structure, features, APIs, change history
├── FLOW.md                           # Runtime flow, invariants, known issues
├── NOTCH.md                          # Notch surface geometry spec
└── DESIGN.md                         # App, Guide Window, and website color tokens
```

Where to look first: `ARCHITECTURE.txt` answers "what exists"; `FLOW.md` answers
"what runs in what order" (startup sequence, permission state machine, per-launcher
timeouts, thread map, invariants, known issues). `NOTCH.md` is the single source
for notch-surface geometry; `DESIGN.md` records the color tokens.

## Current Behavior

Global shortcuts:

| Shortcut | Action |
| --- | --- |
| `Option + .` | Open the menu bar menu |
| `Option + custom key` | Launch the site assigned to that shortcut |
| `Option + ,` | Open Settings |

Launch types:

| Type | Execution | Window control | Accessibility |
| --- | --- | --- | --- |
| `url` | Chrome `--app` mode via `/usr/bin/open` | AX API detects the new Chrome window; optional reuse targets only that launchable's remembered window ID | Required for resize; Automation required for reuse |
| `app` | `NSWorkspace.openApplication` | AXObserver plus polling fallback applies bounds to standard windows, plus resizable non-standard Office windows | Required for resize |
| `finder` | Finder AppleScript opens folder and sets bounds atomically | Finder AppleScript | Automation permission |
| `shell` | User shell runs script with `$SHELL -c` | None | Not required |

Configuration is stored in `~/.chap.json`; `~/.chap.json.bak` is used as the
backup path. Legacy fields are decoded for compatibility and stripped on app
launch where applicable.

URL window reuse is session-scoped ownership, not URL matching. It must never
search user tabs or fall back to the focused/frontmost Chrome window.

Notch Launcher (optional, off by default): `NotchLauncherController` renders a
`.nonactivatingPanel` under the hardware notch that expands on hover and holds
four slots (Sites, Apps, Folders, Scripts, or Screenshots). It is an additive
surface — the status-bar `NSMenu` is always available, including on notchless
Macs. Chap Drop copies dropped files into
`~/Library/Application Support/Chap/Drop/` (originals untouched) and the
Screenshot Shelf reads the system screenshot folder in place. Notch geometry is
computed in `ChapCore/NotchGeometry.swift` (see `NOTCH.md`).

Keep Mac Awake: `KeepAwakeController` holds an IOKit
`PreventUserIdleDisplaySleep` assertion for a `KeepAwakePolicy` preset (30m to
12h). Expiry is wall-clock based via a `DispatchSourceTimer` scheduled with
`wallDeadline`, so sleep time counts; expiry is re-checked on system/screen wake
and when the status menu opens, and a session that expired during sleep ends
quietly (no sound/HUD). State is in memory only, never persisted to config.

Updates: `UpdateController` wraps Sparkle with a fail-closed posture — it starts
only when both `SUFeedURL` and `SUPublicEDKey` are valid in Info.plist, and never
during tests. Daily automatic checks are enabled; automatic download/install is
not.

## Release flow

Daily work stays on `dev`; commit and push only that branch. Releases are cut
locally with `Scripts/release.sh <version>`, which is read-only until `--publish`
is passed. `--publish` bumps version metadata, validates, promotes `dev` → `main`,
tags, builds/notarizes the signed PKG and DMG, publishes the GitHub Release, and
verifies the Pages appcast. Do not bump version numbers by hand — the release
script owns `MARKETING_VERSION`/`CURRENT_PROJECT_VERSION`.

## Rules

Follow the shared rules:

- `.harness/shared/rules/swift-conventions.md`
- `.harness/shared/rules/swift-testing.md`
- `.harness/shared/rules/commit-convention.md`
- `.harness/shared/rules/architecture-docs.md`

Important local expectations:

- Read `FLOW.md` before changing launch, resize, permission, or shortcut behavior.
  Its invariants section lists past regressions; check it before altering window
  targeting, timeouts, or the Chrome serial queue.
- Keep edits scoped to the relevant target: `ChapCore` for testable model logic,
  `Launchers` for launch behavior, `Views` for SwiftUI, and `AppDelegate` for
  lifecycle/menu/window orchestration.
- If behavior, shortcuts, files, launch types, permissions, or config shape
  change, update `ARCHITECTURE.txt`.
- Prefer adding tests for `ChapCore` model, validation, migration, and view-model
  behavior. Do not test SwiftUI layout, `NSWindow`, `NSAlert`, or real `Process`
  execution directly.
- Do not push unless the user explicitly asks.
- Do not add AI attribution or `Co-Authored-By` lines to commits.

## Validation

Run the narrowest relevant check:

```bash
xcrun swift-format lint Sources Tests
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
```

`xcodebuild` writes under Xcode DerivedData. If a sandbox blocks that path, ask for
permission to run the same command outside the sandbox.
