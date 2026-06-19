# Chap

A macOS menubar app for quick-launching sites, apps, folders, and scripts with automatic window sizing.

![Version](https://img.shields.io/badge/version-2.2.9-orange)
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
- **Global Hotkeys** — `⌥1`~`⌥9` to launch, `⌥Q` for menu, `⌥,` for settings
- **Accessibility Aware** — Icon indicates permission status, auto-registers when granted
- **Import/Export** — Share config via JSON file or paste
- **Drag & Drop** — Reorder sites in sidebar, drop `.json` to import
- **Background Mode** — Runs without Dock icon when enabled

## Requirements

- macOS 14.0+ (Sonoma)
- Google Chrome (for URL launch type)
- Accessibility permission (for global hotkeys and app window resizing)

## Install

**One command:**
```bash
curl -sL https://milv0.github.io/chap-app/install.sh | bash
```

**Or manually:**
1. Download from [Releases](https://github.com/milv0/Chap/releases)
2. Move `Chap.app` to `/Applications`
3. Launch and grant Accessibility permission when prompted

**Uninstall:**
```bash
curl -sL https://milv0.github.io/chap-app/uninstall.sh | bash
```
Or use Settings → File menu → Uninstall.

## Usage

### Launch Types

| Type | What it does | Window control |
|------|-------------|---------------|
| URL | Opens in Chrome `--app` mode (no address bar) | AppleScript bounds |
| App | Launches macOS app via NSWorkspace | System Events position/size |
| Finder | Opens folder in Finder | Finder bounds |
| Shell | Runs script via `$SHELL -c` | N/A |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌥Q` | Open menubar menu |
| `⌥1`~`⌥9` | Launch site by number |
| `⌥,` | Open Settings |
| `⌘1`~`⌘9` | Select site in Settings sidebar |
| `⌘E` | Edit selected site |
| `⌘S` | Save changes |
| `⌘/` | User guide |

**Setup:** System Settings → Privacy & Security → Accessibility → enable Chap.
The menubar icon shows a warning badge until permission is granted.

### Config File

Stored at `~/.chap.json`:

```json
{
  "runInBackground": true,
  "sites": [
    {
      "name": "GitHub",
      "url": "https://github.com/",
      "width": 800,
      "height": 600,
      "x": 100,
      "y": 100,
      "launchType": "url",
      "displayName": "Built-in Retina Display"
    },
    {
      "name": "Downloads",
      "url": "",
      "width": 1000,
      "height": 400,
      "x": 100,
      "y": 100,
      "launchType": "finder",
      "folderPath": "~/Downloads"
    }
  ]
}
```

## License

MIT
