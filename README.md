# Chap

A macOS menubar app for quick-launching sites, apps, folders, and scripts with automatic window centering.

![Version](https://img.shields.io/badge/version-1.0.0-orange)
![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menubar Resident** — Always accessible from the status bar
- **4 Launch Types** — URL (Chrome --app), macOS App, Finder folder, Shell script
- **Multi-Monitor** — Target a specific display or auto-detect cursor screen
- **Auto-Center** — Windows always open centered on the target display
- **Size Presets** — Tiny to Full, or set custom width/height
- **Display Minimap** — Visual preview of window placement across all monitors
- **Global Hotkeys** — `⌥.` for menu, `⌥(custom key)` to launch, `⌥,` for settings
- **Accessibility Aware** — Icon indicates permission status, auto-registers when granted
- **Import/Export** — Share config via JSON file or paste
- **Drag & Drop** — Reorder sites in sidebar, drop `.json` to import
- **Launch at Login** — Optional auto-start via macOS Login Items

## Requirements

- macOS 14.0+ (Sonoma)
- Google Chrome (for URL launch type)
- Accessibility permission (for global hotkeys and app window resizing)

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
      "shortcut": "G"
    },
    {
      "name": "Downloads",
      "url": "",
      "width": 1000,
      "height": 400,
      "launchType": "finder",
      "folderPath": "~/Downloads"
    }
  ]
}
```

Windows are always centered on the target display automatically. Position is calculated at launch time based on window size and screen geometry.

> **Migration note:** Legacy fields (`x`, `y`, `hotkey`, `showGhostWindow`, `runInBackground`) are automatically removed from existing config files on app launch.

## License

MIT
