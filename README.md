# Chap

A macOS menubar app for quick-launching sites, apps, folders, and scripts with automatic window centering.

![Version](https://img.shields.io/badge/version-1.0.0-orange)
![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menubar Resident** — Always accessible from the status bar
- **4 Launch Types** — URL (Chrome --app), macOS App, Finder folder, Shell script
- **Multi-Monitor** — UUID-based display selection, with Auto using the cursor screen
- **Auto-Center** — Windows always open centered on the target display
- **Size Presets** — Compact, Focus, Standard, Comfortable, Wide, Tall, Workspace, Max, or Custom
- **Display Minimap** — Auto previews the cursor screen; click to select a display
- **Global Hotkeys** — `⌥.` for menu, `⌥(custom key)` to launch, `⌥,` for settings
- **Accessibility Aware** — Icon indicates permission status, auto-registers when granted
- **Verified Window Placement** — AX position and size are read back before success is reported
- **Serialized Chrome Launches** — Rapid requests remain paired one-to-one with new windows
- **Validated Import/Export** — Imports are normalized, fully validated, and rejected atomically on blocking issues
- **Drag & Drop** — Reorder sites in sidebar, drop `.json` to import
- **Launch at Login** — Optional auto-start via macOS Login Items

## Requirements

- macOS 14.0+ (Sonoma)
- Google Chrome (for URL launch type)
- Accessibility permission (for global hotkeys and URL/app window resizing)
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

**Setup:** System Settings → Privacy & Security → Accessibility → enable Chap.
The menubar icon shows a warning badge until permission is granted.

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

## License

MIT
