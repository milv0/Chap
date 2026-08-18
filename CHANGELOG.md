# Changelog

All notable changes to Chap are documented in this file.

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
