# QuickAccess

A macOS menubar app that launches websites in clean, standalone Chrome windows.

> 🎵 *Vibe-coded with Kiro*

![Version](https://img.shields.io/badge/version-2.2.5-orange)

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- ⚡ **Menubar Resident** — One click to launch any site
- 🪟 **Standalone Windows** — Chrome --app mode, no address bar
- 📐 **Custom Window Sizing** — Set width, height, x, y per site (built-in display)
- 🎯 **Layout Presets** — Center, half, quarter placement
- 📏 **Size Presets** — Tiny to Full, quick selection
- 🎯 **Center Button** — Auto-center with one click
- ⚙️ **Settings GUI** — Modern SwiftUI interface to add/edit/remove sites
- 📦 **Import/Export** — Share settings via JSON
- 🚀 **Launch at Login** — Auto-start toggle
- 🗑️ **Uninstall** — Remove app + config + login item from Settings
- 🔒 **Chrome Session** — Uses your existing Chrome login

## Requirements

- macOS 14.0+
- Google Chrome installed

## Install

**One command:**
```bash
curl -sL https://milv0.github.io/QuickAccess/install.sh | bash
```

**Or manually:**
1. Download [QuickAccess-v2.2.5.zip](https://milv0.github.io/QuickAccess/QuickAccess-v2.2.5.zip)
2. Unzip → folder contains `QuickAccess.app` + `install.sh`
3. Double-click `install.sh` (or right-click → Open) to install

**Uninstall:**
```bash
curl -sL https://milv0.github.io/QuickAccess/uninstall.sh | bash
```

## Usage

1. Click ⚡ in the menubar
2. Click a site → opens in Chrome app window
3. **Settings...** → add/edit/remove sites
4. **Launch at Login** → toggle auto-start

### Share Settings

- Settings → **Export** → save as JSON
- Recipient: Settings → **Import** → apply JSON

### Config File

Stored at `~/.quickaccess.json`:

```json
{
  "runInBackground": true,
  "sites": [
    {
      "name": "Google",
      "url": "https://www.google.com/",
      "width": 600,
      "height": 300,
      "x": 456,
      "y": 341
    }
  ]
}
```

## Author

**Mingyu**
- uqwe00@gmail.com

## License

MIT

---
Built with [Kiro](https://kiro.dev)
