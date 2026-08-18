# Chap

A macOS menubar app for quick-launching sites, apps, folders, and scripts with automatic window centering.

![Version](https://img.shields.io/badge/version-1.0.3-orange)
![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menubar Resident** — Always accessible from the status bar
- **4 Launch Types** — URL (Chrome --app), macOS App, Finder folder, Shell script
- **Multi-Monitor** — UUID-based display selection, with Auto using the cursor screen
- **Auto-Center** — Windows always open centered on the target display
- **Size Presets** — Compact, Focus, Standard, Comfortable, Wide, Tall, Workspace, Max, or Custom
- **Display Minimap** — In normal mode, click a display to select the site target; in Follow Cursor, click a display to configure that monitor's size
- **Global Hotkeys** — Only registered `⌥` combinations reach Chap; normal typing bypasses it
- **Accessibility Aware** — Icon indicates URL/app window-resizing permission status
- **Verified Window Placement** — AX position and size are read back before success is reported
- **Serialized Chrome Launches** — Rapid requests remain paired one-to-one with new windows
- **Validated Import/Export** — Imports are normalized, fully validated, and rejected atomically on blocking issues
- **Drag & Drop** — Reorder sites in sidebar, drop `.json` to import
- **Launch at Login** — Optional auto-start via macOS Login Items

## Requirements

- macOS 14.0+ (Sonoma)
- Google Chrome (for URL launch type)
- Accessibility permission (for URL/app window resizing)
- Automation permission when using Finder folder launch

## Usage

### Launch Types

| Type | What it does | Window control |
|------|-------------|---------------|
| URL | Opens in Chrome `--app` mode (no address bar) | AX API (new window detection via CFEqual) |
| App | Launches macOS app via NSWorkspace | AX API (AXObserver + polling fallback) |
| Finder | Opens folder in Finder | AppleScript bounds |
| Shell | Runs script via `$SHELL -c` | N/A |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥.` | Open menubar menu |
| `⌥(custom key)` | Launch site (per-site shortcut setting) |
| `⌥,` | Open Settings |
| `⌘1`~`⌘9` | Select site in Settings sidebar |
| `⌘N` | Add new site |
| `⌘S` | Save changes |
| `⌘/` | User guide |
| `↑` `↓` | Navigate sidebar |
| `Enter` | Save + exit edit mode |

**Window resizing setup:** System Settings → Privacy & Security → Accessibility → enable Chap.
Global hotkeys work without this permission; the menubar warning badge indicates that URL/app
window resizing is unavailable.

### Config File

Stored at `~/.chap.json`:

```json
{
  "showGuideWindow": true,
  "launchAtLogin": false,
  "sites": [
    {
      "name": "GitHub",
      "url": "https://github.com/",
      "width": 800,
      "height": 600,
      "launchType": "url",
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

> **Migration note:** Legacy fields (`x`, `y`, `hotkey`, `showGhostWindow`, `runInBackground`) are automatically removed from existing config files on app launch.

## Direct Distribution (Developer ID)

Chap’s Accessibility-based window control and Shell launcher are distributed outside the Mac App Store. The full edition uses **Developer ID Application** signing, the Hardened Runtime, and Apple notarization; TestFlight is not a valid test or distribution channel for this edition because it is an App Store sandbox build.

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
Scripts/release.sh 1.0.3

# Production release: version bump, validation, dev → main promotion, tag,
# signed/notarized PKG + DMG, GitHub Release upload, and Pages verification.
Scripts/release.sh 1.0.3 --publish
```

`--publish` must start from a clean `dev` branch that matches `origin/dev`. It uses only local signing identities and the `ChapNotary` keychain profile; credentials are never stored in the repository. The release command is intentionally manual because it changes protected release surfaces.

### Window-control reliability and diagnostics

The URL and App launchers share the same Accessibility bounds pipeline. It follows the proven **size → position → size** order used by [Rectangle](https://github.com/rxhanson/Rectangle) to avoid display-transition clamping, limits unresponsive AX calls to two seconds, temporarily disables `AXEnhancedUserInterface` when an app has enabled it, and verifies final bounds by readback. If an app clamps the requested size, Chap preserves the intended center by applying a corrected position once more.

Debug builds append diagnostics to `~/Library/Logs/Chap/resize_YYYY-MM-DD.csv`. `minSize=WxH` indicates `AXMinSize`/`AXMinimumSize` predicts a clamp; `recentered=(x y)` indicates the center-preserving correction ran; `enhancedUI=disabled` indicates that compatibility path ran. Their absence on a `fully` row is normal: it means the app accepted the requested bounds without needing that recovery path.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and release notes.

## License

MIT
