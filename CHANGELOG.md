# Changelog

All notable changes to Chap are documented in this file.

## [Unreleased]

### Added

- **Collapsible shelves** — Collapse Screenshots or Downloads from the chevron at
  the end of its title (or right-click → Collapse) and it folds into a small
  white icon on the left of the notch's black strip, mirroring Drop, Mirror, and
  Quick Note on the right. The dock keeps its width. Click the icon to bring the
  shelf back. Chap remembers this on this Mac.

### Changed

- **No strip countdown** — The black strip no longer shows the Focus timer. When
  the Focus slot isn't showing, the strip seal stays awake and wags its tail
  while Focus runs; the time left is in the Focus slot and the status menu.

## [2.5.0] — 2026-10-05

### Added

- **Chap the Seal** — Chap's pixel mascot, a baby seal, now rests on the left of
  the notch's black strip. It flicks its tail when you open the notch and now and
  then while it stays open (never with Reduce Motion on), and steps aside for the
  Focus timer while Focus runs.
- **Seal in Focus** — The Focus slot shows the seal instead of the big bolt: it
  sleeps with a rising z while Focus is off, wakes with a tail flick when Focus
  starts, wags its tail the whole time Focus runs (slower once drowsy), blinks
  while it keeps watch, and gets drowsy in the last 30 minutes.
  While the Focus slot is showing, the strip's left side stays empty (no second
  seal, no duplicate clock); in Quick Note mode the strip shows them again.

### Changed

- **Scrollable shelves** — Screenshots and Downloads now keep up to twelve items.
  Four show at a glance; scroll with the trackpad or wheel for the rest. There is
  no scroll bar, only a soft fade at the bottom when more is below.
- **Centered shelf folders** — Clicking the Screenshots or Downloads title opens
  that folder in a Finder window at the Standard size, centered on the screen
  with the pointer, like any Finder launchable.
- **Slimmer Downloads slot** — File names in the Downloads slot are 10pt and the
  slot is 160pt wide instead of 200pt, so the dock is narrower while names show
  about as much as before. Sites and Finder lists stay at 13pt.

## [2.4.2] — 2026-09-29

### Changed

- **Mist panel preset** — Custom panel color presets are now Black and Mist (`#E8ECF8`, a soft blue-gray light), replacing the Guide blue swatch. Any color stays available from the color picker.
- **White strip widgets** — The Drop, Mirror, and Quick Note icons in the notch's
  black strip are white again; only an open tool turns blue. Section icons keep
  the soft Chap blue.

## [2.4.1] — 2026-09-29

### Fixed

- **Live Focus timer** — Turning Focus on or off while the notch is open now shows
  or hides the timer in the notch's top strip right away, without reopening it.

### Changed

- **Greeting** — The welcome screen now says "Hi, I'm your chap."
- **Brand-blue notch icons** — Section and strip icons in the notch use a soft
  Chap blue (lighter on dark backgrounds) while text stays neutral.

## [2.4.0] — 2026-09-29

### Added

- **Focus Mode widget** — A lightning-bolt notch slot for Keep Mac Awake. Chap on
  with 1h, 4h, or 8h; while it runs, the bolt pulses and a countdown shows how
  long is left, from "Fully charged" down to "Landing soon". Chap off to stop. It
  is the same session as Keep Mac Awake in the menu, and the timer in the notch's
  top strip now uses the same bolt instead of a coffee cup.
- **Window icon for Sites** — URL launchables use a browser-window icon in the
  menu, the notch, and Settings, so the lightning bolt now means Focus only.
- **Downloads widget** — A new notch slot shows your four newest downloads with
  their file names and how long ago they arrived. Click to open, drag a file out,
  or right-click to share it or show it in Finder. Click the title to open
  Downloads. Files still downloading are hidden. macOS asks once for access to
  the Downloads folder.
- **Quick Note window** — Open the note in its own floating, resizable window
  from the note toolbar. It stays above other windows while the notch is closed
  and remembers its size and position.

### Changed

- **Your chap in the menu bar** — Chap now introduces itself as a friend: the
  welcome screen says hello, About and the website share one line, and a new
  BRAND.md keeps Chap's voice consistent.
- **Roomier Quick Note** — Clicking the note icon now turns the widget row into a
  wide note across the notch, with a character count and a copy button. Click ×
  or the icon again to return to your widgets.

## [2.3.0] — 2026-09-29

### Added

- **Share dropped files** — Hover a file in Chap Drop and click the gray share
  button (top left) to send it with AirDrop, Messages, Mail, and more. Right-click
  a file for Open, Share…, Show in Finder, and Remove.

### Changed

- **Quick Note in the top strip** — Quick Note moved out of the widget slots to a
  note icon right of Mirror in the notch's black strip. Click it and the note
  opens just below, ready to type. Hide it with Show Quick Note Icon in Settings.
- **Minimum notch width** — The open notch is at least 640pt wide and centers the
  widget row, so a few widgets no longer squeeze it against the notch.
- **Drop box always visible when open** — The open notch shows the Drop box in
  the strip even when it is empty (without a count), so Mirror and Quick Note
  keep a fixed place. The closed notch still shows the badge only when files are
  kept.
- **Screenshot times on the right** — Each screenshot row keeps the thumbnail on
  the left and aligns the time to the row's right edge.
- **Click away to close** — Clicking anywhere outside an open Quick Note or Mirror
  popup, or switching to another app, folds it away.
- **Tighter strip icons** — Mirror now sits right next to the Drop badge instead
  of leaving a wide gap.

## [2.2.2] — 2026-09-29

### Changed

- **Smaller Mirror preview** — The camera preview is narrower (144 × 108) and
  keeps your face centered.
- **Accurate help** — The in-app Q&A now describes choosing Glass appearance and
  material independently.

## [2.2.1] — 2026-09-29

### Fixed

- **Mirror crash** — Clicking the Mirror icon could quit Chap. The camera now
  starts only after its preview is connected, so the two no longer collide.

## [2.2.0] — 2026-09-29

### Added

- **Mirror** — A webcam icon in the black strip beside the notch, next to the
  Drop badge. Click it and your camera, flipped like a mirror, pops open just
  below the strip; nothing is recorded and Chap asks for camera access only the first
  time. Hide it with Show Mirror Icon in Settings → Notch.
- **Quick Note widget** — Type a plain-text note right in the notch. It saves
  as you type, shows when it was last saved, stays out of config export, and keeps the dock open while you
  write; press Esc or click elsewhere to finish.
- **Section dividers** — Thin vertical lines now separate the notch widgets.
- **App icons in the notch** — The Apps widget shows your apps as a two-column
  grid of icons that uses only the rows it needs, with the shortcut letter on
  apps that have one. Hover for the name; click to launch.
- **Six apps** — You can now add up to six apps (Sites and Finder stay at
  four), so the Apps icon grid can fill three rows.

### Changed

- **Add to the section you picked** — In Settings, click the URL, App, or Finder
  heading to highlight that section; + and ⌘N then add a new item there.
- **Finder naming** — The notch widget and section formerly called Folders are
  now called Finder, matching the Finder launch type in Settings and the menu.
- **More legible notch** — Text uses three sizes (13, 11, and 10pt), section
  icons share the heading color instead of competing blues, shortcut keys have
  stronger contrast, and every row lines up at the same height. Screenshots show
  a larger thumbnail and when they were taken ("5 min ago") instead of a cut-off
  file name. Clear Glass gets a light veil for contrast, and new setups default
  to Regular Glass.
- **Edit from the notch** — Click the Sites, Apps, or Finder title in the notch
  to open Settings with that list selected.
- **Plain app launch from the notch** — Clicking an app without a shortcut in
  the notch opens it as-is, without resizing. Apps with a shortcut, Sites, and
  Finder still open centered at their saved size, as do all status-menu and
  Option-shortcut launches.
- **Cleaner shortcut keys** — Sites and Apps show just the key (1, N). Hold
  Option while the notch is open and every keycap turns blue and shows the full
  shortcut (⌥1, ⌥N). Tooltips and VoiceOver always include Option.
- **Right-sized notch columns** — Each widget column now fits its content
  (Sites and Finder 112–170pt, Apps to its icon grid), making
  the dock noticeably narrower. Headings are brighter, the Apps title no longer
  carries an extra ⌥ key, and dropped files show as a compact row of icons with
  one-line names.
- **Six notch slots, no pages** — The notch now shows up to six widgets in one
  row, enough for every widget type, and the page dots and swipe from 2.1 are
  gone. Widgets placed on later pages move into the first free slots.

## [2.1.0] — 2026-09-29

### Added

- **Notch pages** — The notch now has twelve widget slots on three pages of
  four. When more than one page has widgets, dots between the notch and the
  widgets switch pages, and a horizontal trackpad swipe over the dock moves
  left or right. Existing four-slot layouts become the first page.
- **Open the screenshot folder** — Click the Screenshots title in the notch to
  open the folder where macOS saves screenshots.

### Changed

- **Glass material for any appearance** — Clear and Regular Liquid Glass can now
  be chosen with System, Light, or Dark appearance instead of being paired.
- **Notch defaults** — New configurations place Sites, Apps, Folders, and
  Screenshots on the first notch page.

### Removed

- **Shell launch type** — Chap now focuses on opening windows. On first launch,
  Shell launchables are removed after the original configuration is saved to
  `~/.chap.json.shell-scripts.bak`, and a one-time notice lists them. A Scripts
  notch slot becomes Screenshots (or Empty if Screenshots is already placed).
  Importing a file that contains Shell launchables is rejected unchanged.

## [2.0.1] — 2026-09-28

### Fixed

- **Keep Awake after sleep** — A session that ends while the Mac is asleep, for
  example with the lid closed overnight, now ends as soon as the Mac wakes, so
  the status icon returns to its normal color instead of staying blue. Sessions
  use wall-clock timing and an expired session ends quietly, without the sound
  or HUD.

### Changed

- **Interactive website demo** — The notch demo on the Chap site now opens on
  hover or tap, launches Option-shortcut windows that land centered, accepts
  files for Chap Drop, and offers a skippable four-step guided tour.

## [2.0.0] — 2026-09-26

### Added

- **Notch Launcher** — Optional four-slot command surface for Sites, Apps,
  Folders, Scripts, and recent Screenshots, with drag, context-menu, and
  VoiceOver configuration.
- **Chap Drop** — Drag files to the notch, keep local copies in Chap's private
  Drop folder, and open, drag out, or remove them from the dock's file row.
- **Liquid Glass** — Apple Clear/Regular Glass with System/Light/Dark appearance
  on macOS 26+, plus Custom color and opacity on macOS 14+.
- **Notch Keep Awake status** — Blue coffee icon and live `h:mm:ss` countdown in
  the open dock.

### Changed

- **Four launchables per type** — URL, App, Finder, and Shell lists are capped at
  four each to keep the menu and notch predictable.
- **Dedicated Notch settings** — Widget assignment, Custom appearance, and Glass
  previews now live in their own Settings tab.
- **Complete export** — Hidden-menu and notch choices are included in config
  export; import preserves the destination Mac's device-specific notch values.
- **Public website** — Rebuilt as a notch-first Chap 2 product experience.

### Improved

- **Responsive notch lifecycle** — Recalculates geometry after display,
  resolution, arrangement, and clamshell changes.
- **Non-blocking Drop pipeline** — Copies, folder scans, and thumbnail decoding
  run off the main thread with failure feedback and thumbnail caching.
- **Accessibility and contrast** — Keyboard and VoiceOver widget actions,
  accessible Drop file actions, adaptive Custom colors, semantic Glass text,
  and reduced-motion website behavior.

---

## [1.3.8] — 2026-09-23

### Added

- **Safe Quit** — Every Quit request now requires confirmation, with Cancel
  as the default. Confirmed quits release any active Keep Awake session.
- **Keep Awake status indicator** — Active sessions turn both Default and
  Lightning status bar icons Chap blue, returning them to normal when the
  session ends or expires.

### Improved

- **Accessibility readback safety** — Replaced an unsafe generic pointer
  conversion with typed Accessibility values, eliminating its Release warning.
- **Settings and documentation consistency** — Hidden menu state is included
  in manual validation, the settings close flow is simpler, and architecture
  and user guidance are current.

---

## [1.3.7] — 2026-09-22

### Added

- **Keep Awake quit confirmation** — Active sessions require an explicit
  "Quit Anyway" choice before Chap exits; Cancel is the default.

### Improved

- **Type-safe Accessibility readback** — Removed an unsafe generic pointer
  conversion and its Release compiler warning.
- **Settings consistency** — Manual validation now includes hidden menu
  sections, and the settings close flow was simplified without behavior
  changes.
- **Documentation refresh** — Updated architecture, distribution, menu,
  Sparkle, Keep Awake, and historical attribution guidance.

---

## [1.3.6] — 2026-09-22

### Fixed

- **Clearer empty shortcut field** — The compact Shortcut field shows a dash
  instead of the letter "T" when no shortcut is set, so it isn't mistaken
  for an assigned value.

---

## [1.3.5] — 2026-09-22

### Added

- **Persistent shortcut hints** — Settings > General always shows ⌥ .,
  ⌥ ,, and ⌥ (key) so they're easy to recall without checking Q&A.

### Improved

- **No more scrollbar in site settings** — Increased the settings window's
  minimum height and hid the scroll indicator in the site config panel.
- **About Chap moved** — Removed from the menu bar list; click the app icon
  in Settings > General to open it.

---

## [1.3.4] — 2026-09-21

### Improved

- **Quieter Keep Awake start sound** — Switched from Glass to Purr.
- **Leaner status bar menu** — Removed Restart from the menu bar list; it
  remains in the settings window's ⋯ menu.
- **Clearer tab name** — Renamed the "Launchables" settings tab to
  "Launchers".

---

## [1.3.3] — 2026-09-21

### Added

- **Keep Awake icon indicator** — The Lightning status bar icon turns theme
  blue while a Keep Awake session is active and reverts automatically when
  it ends or expires.

---

## [1.3.2] — 2026-09-21

### Improved

- **Keep Awake overlay** — Restyled with Chap's theme accent in the guide
  window's visual language and doubled the on-screen duration.

---

## [1.3.1] — 2026-09-21

### Improved

- **Keep Awake feedback** — Session start, stop, and expiry now show a brief
  centered coffee-cup HUD with a subtle system sound.
- **Compact menu settings** — Menu section visibility is a single row of
  URL / App / Finder / Shell chips in Settings > General.

---

## [1.3.0] — 2026-09-21

### Added

- **Keep Mac Awake** — Menu bar sessions (30 minutes to 12 hours) that keep
  the display awake via an IOKit power assertion; the menu shows remaining
  time and the assertion is always released on expiry, turn-off, or quit.
- **Curated menu** — Per-launch-type visibility toggles in Settings > General
  hide sections from the status bar menu while their Option shortcuts keep
  working.

### Removed

- **CPU-reactive lightning animation** — Removed the 1.2.0 status bar
  animation; leftover `statusBarAnimation` config values are ignored safely.

---

## [1.2.0] — 2026-09-21

### Added

- **CPU-reactive lightning icon** — The Lightning status bar icon can animate
  with CPU load (about 1 fps idle up to 20 fps under full load, sampled every
  3 seconds), with Pulse and Wobble styles selectable in Settings > General.
  CPU sampling runs only while a style is enabled. Speed mapping was adapted
  from [RunCat Neo](https://github.com/runcat-dev/RunCatNeo) (Apache-2.0); the
  feature was removed in 1.3.0.

### Changed

- **English-only product page** — Removed the Korean language toggle from the
  website.

---

## [1.1.16] — 2026-09-21

### Fixed

- **More reliable URL window reuse** — Transient Chrome automation failures
  during window reuse are retried once after a short delay instead of
  immediately falling back to the slower new-window path; permission denials
  still fall back right away.

### Improved

- **Clearer reuse diagnostics** — The underlying automation error is recorded
  in the system log when reuse is unavailable.

---

## [1.1.15] — 2026-09-10

### Improved

- **Deliberate Shell editing** — Saved Shell launchables re-enter edit mode
  only from a click inside the script editor; clicks elsewhere in the panel
  no longer enable editing. Other launch types keep whole-panel activation.

---

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
