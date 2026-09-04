# Changelog

All notable changes to Chap are documented in this file.

## [1.1.14] — 2026-09-04

### Fixed

- **Dark Mode Shortcut field** — The Shortcut input highlight now adapts to
  the system appearance, so its text stays readable in Dark Mode.

### Added

- **Minimum window size notice** — When an app enforces a minimum window size
  larger than the configured size, Chap explains the clamp and shows the
  app's minimum once per launchable and size combination per session.

---

## [1.1.13] — 2026-09-04

### Improved

- **Launcher maintainability** — Restructured the URL and App launch pipelines
  into named phases (baseline, launch, observe, report) with identical
  behavior, timing, and diagnostics.
- **Leaner internals** — Removed dead code, unified duplicated Accessibility
  readback helpers, and moved domain validation to a compile-time-checked
  regex literal.
- **Settings code organization** — Extracted the General tab into its own view
  file; no visual or behavioral changes.
- **Debug diagnostics housekeeping** — Debug builds prune resize diagnostics
  older than 14 days automatically.

---

## [1.1.12] — 2026-08-25

### Fixed

- **Saved Shell editor state** — Shell script editors now become visibly
  disabled after a successful save.
- **Locked saved script text** — Saved script text no longer accepts editing,
  selection, or keyboard focus until edit mode is enabled again.

---

## [1.1.11] — 2026-08-25

### Added

- **Configurable daily update checks** — A General setting controls automatic
  update checks; Sparkle's built-in scheduler checks once per day and shows
  update UI only when a newer version is available. Automatic downloads and
  installation remain disabled.

### Improved

- **Shell save confirmation** — Shell script saves now show a clear Saved
  confirmation after the editor is disabled.

---

## [1.1.10] — 2026-08-25

### Fixed

- **Shell save completion state** — Successful Shell script saves now exit edit
  mode, visibly disabling the editor and its Save button.
- **Recoverable save failures** — Validation and persistence failures keep the
  Shell editor active so users can correct the configuration and retry.

---

## [1.1.9] — 2026-08-24

### Improved

- **Explicit Shell script saving** — Added a dedicated Save button beneath the
  multiline Shell editor so Return remains available for script line breaks.
- **Validated manual saves** — Shell saves now use the same full configuration
  validation and warning flow as other user-triggered saves.

---

## [1.1.8] — 2026-08-24

### Fixed

- **Editable shell scripts** — Removed conflicting SwiftUI tap and focus
  coordination that could immediately release the AppKit script editor's first
  responder, preventing text changes in Shell launchables.
- **Script binding coverage** — Added a regression test that verifies AppKit
  text input reaches the bound Shell script value.

---

## [1.1.7] — 2026-08-23

### Improved

- **Clear reuse control** — The URL reuse setting now uses a dedicated window
  icon, stronger label hierarchy, and a compact single-row layout. Its full row
  dims when the launchable is not being edited.
- **Cleaner menubar actions** — "Check for Updates…" now sits directly above
  "Restart" in the menubar menu.

---

## [1.1.6] — 2026-08-23

### Improved

- **Clear URL reuse guidance** — The in-app Q&A now explains first-launch
  ownership, exact Chrome window reuse, session lifetime, and reset conditions
  in Korean and English.
- **Consistent product documentation** — README, import guidance, website
  history, release notes, and contributor instructions now describe the same
  Chap-owned window behavior.

---

## [1.1.5] — 2026-08-23

### Fixed

- **Chap-owned Chrome window reuse** — Each URL launchable now remembers only
  the Chrome app window it creates after reuse is enabled. User tabs, focused
  windows, and frontmost windows are never searched as fallback targets.
- **Safe reuse invalidation** — Tracked Chrome windows are discarded when the
  window closes, Chrome restarts, reuse is disabled, or the URL changes.
- **Session-scoped ownership** — The first launch opens a new Chrome `--app`
  window and links it only when exactly one new window ID is observed. Links
  remain in memory for the current Chap session and are rebuilt after restart.

---

## [1.1.4] — 2026-08-21

### Fixed

- **Exact Chrome reuse targeting** — URL reuse now applies bounds directly to
  the selected Chrome window ID instead of resolving a focused accessibility
  window, preventing other Chrome windows from being resized.

---

## [1.1.3] — 2026-08-21

### Fixed

- **Correct Chrome reuse placement** — Chap now preserves the Chrome window
  selected by URL reuse, preventing a separately active Chrome window from
  being resized instead.

---

## [1.1.2] — 2026-08-21

### Fixed

- **Reliable Chrome window reuse** — Chap now requests Chrome Automation
  permission directly and remembers the first opened Chrome window for each URL
  launchable during the current app session. This keeps reuse working after a
  login redirect changes the visible URL, while closed windows and Chrome
  restarts safely fall back to URL matching.

---

## [1.1.1] — 2026-08-21

### Fixed

- **Existing Chrome URL window reuse** — Chap now searches every tab, treats
  trailing-slash variants as the same URL, and waits for the matched window to
  become focused before applying its configured placement.

---

## [1.1.0] — 2026-08-21

### Added

- **Optional URL window reuse** — Each URL launchable can bring forward an existing
  Chrome window showing the same address and place it at the configured size and
  display instead of opening another window.
- **Curated product history** — The website now records major feature milestones
  without listing every patch release.
- **Chap product story** — The website connects Chap's seal-inspired name with
  fast Option-key access to apps, URLs, folders, and scripts.

### Improved

- **Roomier settings window** — The default Settings height accommodates the new
  URL option without unnecessary scrolling.

---

## [1.0.5] — Unreleased

### Added

- **Manual update checking** — New "Check for Updates…" menu item triggers a user-initiated Sparkle 2 update check. The updater uses EdDSA (ed25519) signature verification against the embedded public key. No automatic background checks, no scheduling, and no permission dialogs occur — updates are exclusively user-triggered.
- **Fail-closed updater architecture** — Sparkle starts only when both `SUFeedURL` (HTTPS) and `SUPublicEDKey` are present and valid in Info.plist. Incomplete or malformed configuration disables the menu item and prevents any network activity.
- **Appcast generation tooling** — `Scripts/generate-appcast.sh` signs notarized DMGs with the Sparkle CLI, validates XML well-formedness and required enclosure attributes (edSignature, version, url, length), and places the result at `docs/appcast.xml` for GitHub Pages deployment. The release script invokes it automatically when Sparkle CLI environment variables are set.

---

## [1.0.4] — Unreleased

### Added

- **Status bar icon selection** — New "Icon" submenu (immediately before Settings) lets you choose between Default (custom template image) and Lightning (SF Symbols `bolt.fill`). The selection updates the menubar icon immediately and persists as `statusBarIcon` in `~/.chap.json`. Existing configs without the field default to the original icon. The Accessibility-denied warning badge remains unaffected by this setting.

### Improved

- **Shortcut–site copy clarity** — English and Korean landing-page wording now says users press their configured shortcut, replacing the previous copy that referred to pressing a letter.

---

## [1.0.3] — 2026-08-18

### Added

- **Import format guidance** — When an import is blocked by validation errors, the failure alert now includes a "Show Expected Format" button that displays required fields, optional fields, and a minimal valid JSON example covering all four launch types. The reference is copyable so users can fix their file without consulting external documentation.
- **AppLauncher observation policy tests** — The `resizeObservationPolicy` predicate (timeout, post-resize grace, focused-fallback delay, Office detection) is now a pure function exposed for unit testing. `AppObservationPolicyTests` covers the full decision table from FLOW.md §7.2: normal vs Office apps, running vs cold-start, and end-of-observation predicates.

### Improved

- **Chrome prerequisite & onboarding UX** — Clearer messaging when Chrome is not installed or not configured, and improved English copy on the Accessibility permission alert to reduce ambiguity about what the permission enables.
- **Korean landing-page typography** — Adjusted font weights and letter-spacing on the GitHub Pages landing page for better Korean text rendering.

### Fixed

- No user-facing bug fixes in this release.

---

## [1.0.2] — 2026-08-14

Initial public release with Developer ID signing, notarization, and PKG/DMG distribution.

### Highlights

- Menubar launcher with URL, App, Finder, and Shell launch types
- Multi-monitor UUID-based display targeting with Follow Cursor mode
- AX API window centering with readback verification
- Serialized Chrome launch queue preventing window/request mismatch
- Validated import/export with atomic rejection on blocking issues
- Global hotkeys via RegisterEventHotKey (independent of Accessibility permission)
- PKG primary installer with signed DMG fallback
- GitHub Pages landing page
