# Chap

**Your chap in the menu bar.** A friend that lives in your menu bar and notch: it opens your sites, apps, and folders and lands each window right where it belongs.

> *chap* (n., British) — a friend, a good fellow · *chap* — the snap of a window landing in place. See [BRAND.md](BRAND.md) for Chap's identity and voice.

![Version](https://img.shields.io/badge/version-2.19.4-orange)
![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Notch Launcher** — An optional six-slot command surface that expands from the MacBook notch; on a Mac without a notch it opens when you point at the middle of the menu bar, and the classic status menu always remains available
- **Chap Drop** — Drag files to the notch to keep them at hand (Chap remembers the originals; only temporary items are copied) and drag them back out from the dock's Finder-style file row
- **Liquid Glass or Custom** — Use Apple Clear/Regular Liquid Glass on macOS 26+, or a custom color and opacity on every supported macOS version
- **Chap the Seal** — The app icon, and the same pixel seal rests on the left of the notch's black strip: it flicks its tail when you open the notch, splashes into the water and back when Keep Awake starts, wags its tail while Keep Awake runs, and flicks it when you check off a to-do
- **To-do** — A short checklist in a notch slot: click Add (or anywhere in an empty slot) and type, Enter to add the next, click a circle to check it off (double-click to edit, hover and click × to delete); finished items stay in place, checked off, until you click Clear. When everything is done the slot says "All done." with Back and Clear. Up to four items, so the list fits at a glance, and the slot widens to fit your longest item (it settles each time you open the notch); clear finished ones to make room. Kept only on this Mac (no permissions, no sync)
- **Mirror and Quick Note** — Check your camera before a call, or jot a note, right from the notch
- **Keep Awake & Timer Dial** — One notch slot handles both: switch (click the icon in its title, or swipe with two fingers) between a 1–12-hour Keep Awake dial (the same session as Keep Awake in the menu bar) and a 5–60-minute Timer dial. Drag the arc to set the duration, click the center to start, and watch it wind down; while a timer runs, its time sits beside the closed notch and Chap plays a sound and shows "Time's up" when it ends
- **Layouts (demo)** — Arrange your standard app windows, capture their displays, sizes, and positions, then restore the whole layout from the menu bar or the Layouts tab of the notch Apps slot; app names and window titles stay in a local file on this Mac
- **Downloads Shelf** — See your newest downloads in a notch slot (four at a glance, scroll for up to twelve) with their names and age (rest on a cut-off name to see it in full); click to open, drag out, or right-click to share or show in Finder
- **Screenshot Shelf** — Place recent screenshots in a notch slot (four at a glance, scroll for up to twelve) without moving or duplicating the originals; click the Screenshots or Downloads title to open that folder in a centered Standard-size Finder window. Collapse either shelf to a small white icon on the left of the notch's black strip when you don't want to see the files; the dock narrows to fit. A folded shelf opens by itself when you open the notch within 10 minutes of a new screenshot or download, without changing your setting. Settings → Notch → Screenshots shows which folder the shelf reads; **Change…** opens the macOS Screenshot app, where Options → Other Location… lets you pick or create a folder (Chap only reads that setting, never writes it). If screenshots land on the Desktop, other images there join the shelf too, so a folder of their own works best
- **Menubar Resident** — Always accessible from the status bar, including notchless Macs and while the notch launcher is off
- **3 Launch Types** — URL (Chrome --app), macOS App, Finder folder
- **Multi-Monitor** — UUID-based display selection, with Auto using the cursor screen
- **Auto-Center** — Windows always open centered on the target display
- **Size Presets** — Pick a window-shape thumbnail: a landscape row (Compact, Standard, Comfortable, Wide, Workspace, Max — Max fills the full height left by the menu bar and Dock) and a portrait row (Sidebar, Tall, Document, Half), or Custom
- **Display Minimap** — In normal mode, click a display to select the site target; in Follow Cursor, click a display to configure that monitor's size
- **Global Hotkeys** — Only registered `⌥` combinations reach Chap; normal typing bypasses it
- **Accessibility Aware** — Icon indicates URL/app window-resizing permission status
- **Verified Window Placement** — AX position and size are read back before success is reported
- **Serialized Chrome Launches** — Rapid requests remain paired one-to-one with new windows
- **Owned URL Window Reuse** — Reopen only the Chrome `--app` window created by that launchable
- **Validated Import/Export** — Imports are normalized, fully validated, and rejected atomically on blocking issues
- **Drag & Drop** — Reorder sites in sidebar, drop `.json` to import
- **Launch at Login** — Optional auto-start via macOS Login Items
- **Menu Bar Icon** — Pick the default Chap icon, a lightning bolt, or Chap the Seal (a pixel seal drawn in outline) in Settings > General; it turns Chap blue while Keep Awake runs
- **Keep Awake** — Menu bar sessions (30m to 12h) that keep the display awake; starting or ending one shows Chap in the middle of the screen (on the built-in display with the notch), and active sessions turn the status icon Chap blue and release on expiry or confirmed quit. Sessions use wall-clock timing, so they end on schedule even across sleep, and a session that expired while the Mac slept is released quietly (no sound or HUD) on wake or when the status menu opens
- **Cover Screens** — Cover every screen in black while you're on break: ⌥L, the menu bar item, or the moon icon in the notch strip turns it on, a tap of ⌥ Option brings you back, and pressing any key 10 times quickly lifts it if you forget. Set a line to show under the clock ("Back in 10 minutes") in Settings > Tools. With more than one screen, the clock stays on the built-in display and Chap keeps you company on the others, flicking its tail now and then and drifting slowly around the screen like a screensaver (it stays put with Reduce Motion on). It holds the display awake on its own, so it works with or without a Keep Awake session and stays up when a session ends. It is a cover, not a lock: no password, and quitting Chap lifts it
- **Safe Quit** — Every Quit request requires confirmation
- **Curated Menu** — Hide launch-type sections from the menu while keeping their Option shortcuts active
- **Focused Lists** — URL and Finder allow up to four launchables each and App up to six, keeping the menu and notch predictable

## Requirements

- macOS 14.0+ (Sonoma)
- A MacBook notch for the Notch Launcher's hardware look; without one the launcher still opens from the middle of the menu bar, and all classic menu and Option-shortcut features work either way
- macOS 26+ (Tahoe) for Liquid Glass; Custom style works on macOS 14+
- Google Chrome (for URL launch type)
- Accessibility permission (for URL/app window resizing and Layouts)
- Automation permission when reusing Chrome URL windows or using Finder folder launch
- Downloads folder access only if you place the Downloads widget (macOS asks once)
- Camera permission only if you use the notch Mirror (asked the first time you click its icon)

## Usage

### Launch Types

| Type | What it does | Window control |
|------|-------------|---------------|
| URL | Opens in Chrome `--app` mode (no address bar) | AX baseline-difference detection, then tracked window ID |
| App | Launches macOS app via NSWorkspace | AX API (AXObserver + polling fallback) |
| Finder | Opens folder in Finder | AppleScript bounds |

### Chrome Window Reuse

`Reuse Existing Window` (URL launchables, under Window) is scoped to each URL launchable. On its first launch
after reuse is enabled, Chap snapshots Chrome window IDs, opens a new `--app`
window, and remembers it only when the before/after difference identifies exactly
one new window. Later launches activate and resize that exact window ID.

Chap never searches regular Chrome tabs by URL, title, focus, or frontmost state.
The tracked link is cleared when the window closes, Chrome restarts, the configured
URL changes, or reuse is disabled. Tracking is in memory only, so restarting Chap
causes the next launch to create and link a new window.

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥.` | Open menubar menu |
| `⌥(custom key)` | Launch site (per-site shortcut setting) |
| `⌥,` | Open Settings |
| `⌥N` | Open Quick Note (change or turn off in Settings → Tools; launcher shortcuts cannot use this key) |
| `⌥L` | Cover Screens (change or turn off in Settings → Tools; launcher shortcuts cannot use this key) |
| `⌘1`~`⌘9` | Select site in Settings sidebar |
| `⌘N` | Add new site |
| `⌘S` | Save changes |
| `⌘/` | User guide |
| `↑` `↓` | Navigate sidebar |
| `Enter` | Save + exit edit mode |

**Window resizing setup:** System Settings → Privacy & Security → Accessibility → enable Chap.
Global hotkeys work without this permission; the menubar warning badge indicates that URL/app
window resizing is unavailable.

### Layouts (demo)

Arrange the standard app windows you want to keep, then choose **Layouts → Capture Layout…** from the status menu. Select up to six app windows, pick the display each one opens on (with more than one screen: any connected display, or Follow Cursor), name the layout, and place the Apps widget in **Settings → Notch** if you want one-click restore from its Layouts tab under the notch. Chap keeps up to four layouts. Saved layouts also appear in **Settings → Launchers** under their own Layouts section, below URL, App, and Finder. Select one to rename it, see every window laid out on its display, move a window to another display, leave a window out, open it, or delete it. **Update Positions** saves where that layout's apps' windows are right now (apps that aren't open keep their saved spot). **Layouts → Edit Layouts…** in the status menu and **Edit…** on a notch tile open the same page. Remove one there, or from the notch right-click menu.

A layout stores the app bundle, local app path, window title, display UUID, and the window frame relative to that display's visible area. It lives only at `~/Library/Application Support/Chap/Layouts.json`; it is not synced or included in config Export. If the saved display is disconnected, Chap fits the same relative layout on the cursor display. Accessibility permission is required to read and restore window bounds.

The demo deliberately handles only a representative standard, non-minimized, non-full-screen window per app. When an app has several windows and Chap cannot identify one unambiguously, it leaves that app out instead of guessing. Regular browser tabs and document reopening are not promised. Chap doesn't move windows between desktops (Spaces), since macOS has no public API for it; to keep apps together, right-click an app's Dock icon → Options → Assign To → This Desktop or All Desktops.

### Config File

Stored at `~/.chap.json`:

```json
{
  "showGuideWindow": true,
  "launchAtLogin": false,
  "optionShortcutsEnabled": true,
  "statusBarIcon": "default",
  "hiddenMenuLaunchTypes": [],
  "notchLauncherEnabled": false,
  "notchPanelStyle": "custom",
  "notchGlassAppearance": "system",
  "notchGlassMaterial": "regular",
  "notchPanelOpacity": 0.6,
  "notchPanelColorHex": "#000000",
  "notchWidgets": ["screenshots", "downloads", "apps", "todo", "awake", "launchers"],
  "notchMirrorEnabled": true,
  "notchQuickNoteEnabled": true,
  "notchQuickNoteShortcut": "N",
  "coverScreensShortcut": "L",
  "notchCollapsedWidgets": ["screenshots", "downloads"],
  "sites": [
    {
      "name": "GitHub",
      "url": "https://github.com/",
      "width": 800,
      "height": 600,
      "launchType": "url",
      "reuseExistingWindow": false,
      "displayName": "Built-in Retina Display",
      "displayIdentifier": "DISPLAY-UUID",
      "windowSizePreset": "standard",
      "shortcut": "G"
    },
    {
      "name": "Downloads",
      "url": "",
      "width": 1000,
      "height": 400,
      "launchType": "finder",
      "windowSizePreset": "compact",
      "folderPath": "~/Downloads"
    }
  ]
}
```

Windows are always centered on the target display automatically. If `displayName` and `displayIdentifier` are omitted, Chap opens on the cursor screen. Legacy name-only display settings are augmented with a UUID only when the connected-name match is unique; connected UUIDs refresh the display name, while ambiguous or disconnected displays are preserved and shown for manual reselection. Size presets are recalculated at launch time: Auto display uses the built-in display as the preset reference, then fits the result to the cursor screen; an explicit display uses that selected display as the reference. Set `windowSizePreset` to `null` or omit it to use the stored custom `width` and `height`.

For URL entries, `reuseExistingWindow: true` enables the per-launchable,
Chap-created Chrome window behavior described above. It does not reuse arbitrary
tabs that happen to show the same URL.

> **Migration note:** Legacy fields (`x`, `y`, `hotkey`, `showGhostWindow`, `runInBackground`) are automatically removed from existing config files on app launch. Legacy notch styles `black` and `iceberg` migrate to `custom`. Chap 2.1 removed the Shell launch type: on first launch, Shell launchables are removed from `~/.chap.json` after the original is saved to `~/.chap.json.shell-scripts.bak`, and Chap shows a one-time notice. A Scripts notch slot becomes Screenshots, or Empty if Screenshots is already placed. Importing a file that contains Shell launchables is rejected without changing anything.

### Notch Launcher and Chap Drop

Enable the feature in **Settings → Notch**. Under **Slots**, the first two slots belong to the Screenshots and Downloads shelves, in that order (click each to turn it on or off; a folded shelf and its slot stay on the left), and you drag Launchers, Apps, Keep Awake, or To-do into the other four, so every widget fits at once. **Launchers** holds the Sites and Finder lists, and **Apps** holds the app icons and your Layouts, each with icon tabs in its title row; click a tab icon or the empty part of the title row, or swipe with two fingers on the trackpad (Chap remembers the last tab); lists and icons stay in separate slots. Chap 2.16 folds older Sites, Finder, and Layouts slots into these in place; context-menu and VoiceOver actions provide the same controls without drag and drop. Hover the hardware notch to open the dock. Changing display resolution, arrangement, or clamshell state automatically recalculates its geometry.

Custom style supports a background color and opacity. On macOS 26+, Glass uses Apple's public Liquid Glass API: Appearance (System/Light/Dark) and Material (Clear/Regular) are chosen independently, so any appearance can use either material, and System follows macOS. Glass text uses native semantic foregrounds.

The **Apps** widget shows up to six apps as a grid of icons (two columns for up to four, three for five or six), with Layouts on the next tab. Shortcut keys on Sites and Apps show just the key (`1`, `N`); hold Option while the dock is open and they light up as `⌥1`, `⌥N`; hover for the name and click to launch. Sites and Finder stay as lists. Point at the current tab's name and click the › beside it to edit that list in Settings; the name itself doesn't open anything, so switching tabs never pops Settings open by mistake.

**Mirror** sits as a webcam icon in the black strip beside the notch, just right of the Drop box (the open notch always shows the box; the count appears only when files are kept). Click it and your built-in camera, flipped like a mirror, pops open just below the strip; it turns off when you close the dock or click ×. Turn the icon off with **Show Mirror Icon** in Settings → Notch. The green camera light shows while it runs; nothing is recorded or saved. Chap asks for camera access only the first time you click the Mirror icon.

**Cover Screens** is a moon icon right of Quick Note. Click it and the dock folds while every screen goes black; tap ⌥ Option to come back. When you come back, Chap says "Welcome back" for a moment. Once the screens are covered the notch is covered too, so come back with ⌥, not the icon. The icon switch is in Settings → Notch → Notch Icons; the ⌥L shortcut and the message are in Settings → Tools, and turning the icon off keeps ⌥L and the menu bar item.

**Quick Note** is a note icon right of Mirror in the black strip. Click it, or press **⌥N** anywhere, and the dock folds away while a floating, resizable note window opens attached just below the notch; drag it anywhere afterwards (Chap remembers its size, and it stays open while the notch is closed). The window has a character count, a copy button, and **Show Backups**. Press **Esc** to close it; whatever you typed is saved first. Change or clear the shortcut under **Settings → Tools**; it works whether or not the notch launcher is on, and if a site already uses the key, the site keeps it. The note saves as you type, and right away when you click anywhere else; the bottom-right corner shows "Saved" with the time or date. It lives at `~/Library/Application Support/Chap/QuickNote.txt` (up to 20,000 characters); it is not part of config export.

Before overwriting the note, Chap keeps the previous version in `~/Library/Application Support/Chap/QuickNote Backups/` at most every 10 minutes, and right away when a long note loses more than half its text (for example after Select All → Delete). The newest ten backups are kept. If the note file ever can't be read, Chap moves it to the same folder as `QuickNote.unreadable-<time>.txt` instead of treating it as empty; if it can't even move it, the note stays read-only so the file is never overwritten.

Dropping a file on the notch or Drop badge opens the main dock with a translucent **Drop here** layer. Chap keeps a reference to each original instead of a copy, so it takes no extra disk space; if you move or rename the file, Chap follows it, and if you delete it, it leaves Chap Drop too. Only items from temporary locations (such as a picture dragged from a browser) are copied into `~/Library/Application Support/Chap/Drop/` so they don't vanish. Removing an item from Chap Drop never deletes the original. Hover a file to share it (AirDrop, Messages, Mail, …) or remove it; right-click for the same actions plus Show in Finder. Drop files remain until you remove them from Chap. Import preserves the destination Mac's device-specific notch choices, while Export records the complete current config.

## Direct Distribution (Developer ID)

Chap’s Accessibility-based window control is distributed outside the Mac App Store. The full edition uses **Developer ID Application** signing, the Hardened Runtime, and Apple notarization; TestFlight is not a valid test or distribution channel for this edition because it is an App Store sandbox build.

### Build and notarize

1. Create and install both `Developer ID Application` and `Developer ID Installer` certificates for team `JC4BNFSKBN`: [Apple Developer Help](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/).
2. Create a local notarytool keychain profile. Do not commit the app-specific password:
   ```bash
   xcrun notarytool store-credentials ChapNotary \
     --apple-id "$APPLE_ID" \
     --team-id JC4BNFSKBN \
     --password "$APP_SPECIFIC_PASSWORD"
   ```
3. Build the signed PKG primary installer. It installs Chap into `/Applications` through macOS Installer and also emits a signed DMG for manual installation:
   ```bash
   Scripts/build-release-pkg.sh
   ```
4. Submit, staple, and verify the primary installer with Gatekeeper:
   ```bash
   NOTARYTOOL_KEYCHAIN_PROFILE=ChapNotary \
     Scripts/notarize-release-pkg.sh build/release/Chap-<version>-<build>.pkg
   ```

The PKG is the primary distribution artifact: it avoids a mounted disk image and uses the standard macOS Installer flow. The DMG remains available as a manual drag-to-Applications fallback. The notarization scripts wait for Apple’s decision, staple the accepted ticket, and verify the installer signature and Gatekeeper assessment. See [Apple’s notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) for credential alternatives and troubleshooting.

### Release automation

Daily development stays on `dev`: commit and push only that branch. The local release command is intentionally non-mutating unless `--publish` is explicit:

```bash
# Read-only preflight: validates release prerequisites and prints the plan.
Scripts/release.sh 2.19.4

# Production release: version bump, validation, dev → main promotion, tag,
# signed/notarized PKG + DMG, GitHub Release upload, and Pages verification.
Scripts/release.sh 2.19.4 --publish
```

`--publish` must start from a clean `dev` branch that matches `origin/dev`. It uses only local signing identities and the `ChapNotary` keychain profile; credentials are never stored in the repository. The release command is intentionally manual because it changes protected release surfaces.

### Window-control reliability and diagnostics

The URL and App launchers share the same Accessibility bounds pipeline. It follows the proven **size → position → size** order used by [Rectangle](https://github.com/rxhanson/Rectangle) to avoid display-transition clamping, limits unresponsive AX calls to two seconds, temporarily disables `AXEnhancedUserInterface` when an app has enabled it, and verifies final bounds by readback. If an app clamps the requested size, Chap preserves the intended center by applying a corrected position once more.

Debug builds append diagnostics to `~/Library/Logs/Chap/resize_YYYY-MM-DD.csv`. `minSize=WxH` indicates `AXMinSize`/`AXMinimumSize` predicts a clamp; `recentered=(x y)` indicates the center-preserving correction ran; `enhancedUI=disabled` indicates that compatibility path ran. Their absence on a `fully` row is normal: it means the app accepted the requested bounds without needing that recovery path.

### Sparkle update system

Chap uses [Sparkle 2](https://sparkle-project.org/) (pinned at 2.9.6) for update checks. The architecture is **fail-closed**: the updater starts only when both `SUFeedURL` and `SUPublicEDKey` are present and valid in Info.plist. With both configured, Sparkle's built-in scheduler checks once per day, and "Check for Updates…" in the menubar remains available for user-initiated checks at any time.

**Current state:** The updater is fully configured. Daily automatic checks are enabled by default and can be toggled in Settings > General; automatic checks finish silently when the app is up to date and show Sparkle's update UI only when a newer version is available.
- `SUFeedURL` = `https://milv0.github.io/Chap/appcast.xml`
- `SUPublicEDKey` = embedded (EdDSA ed25519 public key)
- `SUEnableAutomaticChecks` = `true` (default on, no permission prompt; user-controllable in Settings)
- `SUScheduledCheckInterval` = `86400` (24 hours)
- `SUAllowsAutomaticUpdates` = `false` (no automatic download or installation)

`docs/appcast.xml` is the live signed feed; each `--publish` release appends a signed enclosure entry via `Scripts/generate-appcast.sh`.

**Appcast publishing (for future releases):**

After artifacts are notarized, the release script automatically invokes `Scripts/generate-appcast.sh` when `SPARKLE_BIN_DIR` or `SPARKLE_GENERATE_APPCAST` is set:

```bash
# Set the Sparkle CLI location (one of):
export SPARKLE_BIN_DIR=/path/to/Sparkle/bin
# or
export SPARKLE_GENERATE_APPCAST=/path/to/generate_appcast

# The release script calls generate-appcast.sh automatically.
# For manual invocation after a release:
Scripts/generate-appcast.sh build/release/Chap-<version>-<build>.dmg
```

The script signs the notarized DMG with the operator's Keychain-stored EdDSA private key, updates the feed with proper enclosure attributes (edSignature, version, URL, length), validates the XML, and places the result at `docs/appcast.xml` for GitHub Pages deployment.

**Design decisions:**
- `SUEnableAutomaticChecks` is `true` by default so scheduled daily checks work without a permission dialog; the Settings > General toggle writes Sparkle's own persisted setting.
- `SUAllowsAutomaticUpdates` stays `false` — updates are downloaded and installed only after the user accepts Sparkle's update prompt.
- The updater is never started in test processes, keeping tests network-free.
- The EdDSA private key lives only in the operator's Keychain; it is never committed, exported, or logged.
- Sparkle CLI resolution is fail-closed: scripts abort with an actionable message if tools are not found.
- Appcast validation checks XML well-formedness and required Sparkle enclosure attributes before accepting an update.
- No `com.apple.security.network.client` entitlement is added; Chap is a non-sandboxed Developer ID app.

**Live-release validation notes:**
- The signed feed is live and each release is validated end-to-end during `--publish` (notarized DMG, signed enclosure, Pages deployment).
- Delta updates are generated automatically by `generate_appcast` when multiple versioned archives are present in the staging directory.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.
See [DESIGN.md](DESIGN.md) for app, Guide Window, and website color tokens.
See [BRAND.md](BRAND.md) for Chap's identity (your friend in the menu bar), voice rules, and approved copy.

The website's Product history is intentionally curated. Add an entry only when
a release introduces a major user-facing capability or meaningfully changes a
core workflow; routine fixes and visual adjustments stay in release notes.

## Acknowledgments

Chap does not copy source code from other projects. The techniques below were
adapted from open-source projects and re-implemented independently; they are
credited here and at the corresponding code sites:

- [Rectangle](https://github.com/rxhanson/Rectangle) (MIT, © Ryan Hanson;
  based on Spectacle by Eric Czarny) — the production-proven Accessibility
  resize techniques Chap's window pipeline follows: the
  **size → position → size** apply order, the `AXEnhancedUserInterface`
  disable-and-restore workaround, and the `AXMinSize` → `AXMinimumSize`
  minimum-size probing (see “Window-control reliability and diagnostics”;
  credited in `AXResizePolicy.swift` and `LauncherUtils.swift`).

## License

MIT
