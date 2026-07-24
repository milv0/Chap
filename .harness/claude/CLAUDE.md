# Chap - Claude Code Project Instructions

This file is loaded by Claude Code for this repository. Keep it aligned with
`README.md`, `ARCHITECTURE.txt`, and the shared rules under `.harness/shared/rules/`.

## Project Snapshot

Chap is a macOS 14+ menu bar launcher written in Swift, AppKit, and SwiftUI. It
launches URLs, macOS apps, Finder folders, and shell scripts, then centers
resizable windows on the selected display.

The project is XcodeGen-based:

```bash
xcodegen generate
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" build
xcodebuild -scheme Chap -configuration Debug -destination "platform=macOS" test
```

There is no `Package.swift` and no checked-in GitHub Actions release workflow at
the moment. Use Xcode or `xcodebuild`, not `swift test`.

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
├── Sources/
│   ├── Chap/                         # App target
│   │   ├── main.swift                # NSApplication entry point
│   │   ├── AppDelegate.swift         # Lifecycle, menu, config I/O, hotkeys
│   │   ├── Launchers/                # URL/App/Finder/Shell launch behavior
│   │   └── Views/                    # SwiftUI settings, QA, onboarding UI
│   └── ChapCore/                     # Models, validation, view model, logging
├── Tests/ChapCoreTests/              # Swift Testing unit tests
├── Resources/                        # App and status bar icons
├── assets/icons/                     # Source SVG icon assets
└── ARCHITECTURE.txt                  # Human-readable architecture notes
```

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
| `url` | Chrome `--app` mode via `/usr/bin/open` | AX API detects the new Chrome window and applies bounds | Required for resize |
| `app` | `NSWorkspace.openApplication` | AXObserver plus polling fallback applies bounds to standard windows, plus resizable non-standard Office windows | Required for resize |
| `finder` | Finder AppleScript opens folder and sets bounds atomically | Finder AppleScript | Automation permission |
| `shell` | User shell runs script with `$SHELL -c` | None | Not required |

Configuration is stored in `~/.chap.json`; `~/.chap.json.bak` is used as the
backup path. Legacy fields are decoded for compatibility and stripped on app
launch where applicable.

## Rules

Follow the shared rules:

- `.harness/shared/rules/swift-conventions.md`
- `.harness/shared/rules/swift-testing.md`
- `.harness/shared/rules/commit-convention.md`
- `.harness/shared/rules/architecture-docs.md`

Important local expectations:

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
