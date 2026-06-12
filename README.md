# QuickAccess

A macOS menubar app that launches websites in clean, standalone Chrome windows.

> 🎵 *Vibe-coded with Kiro*

![Version](https://img.shields.io/badge/version-2.2.8-orange?v=2)

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- ⚡ **Menubar Resident** — One click to launch any site
- 🪟 **Standalone Windows** — Chrome --app mode, no address bar
- 🖥️ **Multi-Monitor Support** — Choose which display each site opens on
- 📐 **Custom Window Sizing** — Set width, height per site
- 🎯 **Always Center** — Auto-center windows on any display
- 🎯 **Layout Presets** — Center, half, quarter placement
- 📏 **Size Presets** — Tiny to Full, quick selection
- 🗺️ **Multi-Monitor Minimap** — See all displays and window position at a glance
- ⚙️ **Settings GUI** — Modern SwiftUI interface to add/edit/remove sites
- 📦 **Import/Export** — Share settings via JSON
- 🗑️ **Uninstall** — Remove app + config + login item from Settings
- 🔒 **Chrome Session** — Uses your existing Chrome login

## Requirements

- macOS 14.0+
- Google Chrome installed

## Install

**One command:**
```bash
curl -sL https://milv0.github.io/quickaccess-app/install.sh | bash
```

**Or manually:**
1. Download [QuickAccess-v2.2.8.zip](https://milv0.github.io/quickaccess-app/QuickAccess-v2.2.8.zip)
2. Unzip → folder contains `QuickAccess.app` + `install.sh`
3. Double-click `install.sh` (or right-click → Open) to install

**Uninstall:**
```bash
curl -sL https://milv0.github.io/quickaccess-app/uninstall.sh | bash
```

## Usage

1. Click ⚡ in the menubar
2. Click a site → opens in Chrome app window
3. **Settings...** → add/edit/remove sites, choose display, set window size

### Display Selection

Each site can target a specific monitor or use **Auto** (opens on whichever screen your cursor is on). The minimap shows all connected displays with the window position preview.

### Always Center

Enable **Always Center** in Settings to automatically center all site windows on their target display. Only set the window size — positioning is handled automatically.

### Keyboard Shortcuts

Launch sites without touching the mouse:

| Shortcut | Action |
|----------|--------|
| ⌥Q | Open the menubar menu |
| ⌥1 | Launch 1st site |
| ⌥2 | Launch 2nd site |
| ... | ... |
| ⌥9 | Launch 9th site |
| ⌥, | Open Settings |

**Setup:** System Settings → Privacy & Security → Accessibility → add QuickAccess and enable.

### Share Settings

- Settings → **Export** → save as JSON
- Recipient: Settings → **Import** → apply JSON

### Config File

Stored at `~/.quickaccess.json`:

```json
{
  "runInBackground": true,
  "alwaysCenter": true,
  "sites": [
    {
      "name": "Google",
      "url": "https://www.google.com/",
      "width": 600,
      "height": 300,
      "x": 456,
      "y": 341,
      "displayName": "V28UE-Mv2"
    }
  ]
}
```

## Development

```bash
# Open in Xcode (Cmd+R to run, Cmd+U to test)
open QuickAccess.xcodeproj

# CLI build & test
xcodebuild -scheme QuickAccess -destination "platform=macOS" build
xcodebuild -scheme QuickAccess -destination "platform=macOS" test

# Regenerate .xcodeproj after editing project.yml
xcodegen generate
```

### Project Structure

```
Sources/
├── QuickAccess/          ← App target (AppDelegate, Views, entry point)
└── QuickAccessCore/      ← Core logic (Models, Validation, ViewModel)
Tests/
└── QuickAccessCoreTests/ ← 21 tests (Swift Testing)
```

## Author

**Mingyu**, **Seunghun**

## License

MIT

---
Built with [Kiro](https://kiro.dev)
