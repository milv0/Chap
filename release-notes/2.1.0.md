# Chap 2.1.0

Chap 2.1 focuses on what it does best — opening windows and landing them
centered — and gives the notch more room.

## Added

- **Notch pages** — The notch now holds up to twelve widgets on three pages of
  four. When more than one page has widgets, dots appear between the notch and
  the widgets; click a dot or swipe left or right on the trackpad to switch
  pages. Your existing layout becomes the first page.
- **Open the screenshot folder** — Click the Screenshots title in the notch to
  open the folder where macOS saves your screenshots.

## Changed

- **Glass material for any appearance** — Choose Clear or Regular Liquid Glass
  with System, Light, or Dark appearance. They are no longer paired.
- **Notch defaults** — New setups place Sites, Apps, Folders, and Screenshots
  on the first notch page.

## Removed

- **Shell launch type** — Chap no longer runs shell commands. On first launch,
  any Shell launchables are removed from your configuration after the original
  file is saved to `~/.chap.json.shell-scripts.bak`, and Chap lists what was
  removed once. A Scripts notch slot becomes Screenshots, or Empty if
  Screenshots is already placed. Importing a configuration that contains Shell
  launchables is rejected without changing anything.

## Notes

- macOS 14.0+ is required. Liquid Glass requires macOS 26+.
- Earlier Chap versions can still read the new configuration; they show only
  the first notch page.
