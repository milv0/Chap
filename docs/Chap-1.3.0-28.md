# Chap 1.3.0

## Added

- **Keep Mac Awake** — Start a session from the menu bar (30 minutes, 1, 4,
  8, or 12 hours) to keep your display awake. The menu shows the remaining
  time, sessions end automatically on expiry, and quitting Chap always
  releases the assertion.
- **Curated menu** — Hide any launch-type section (URL, App, Finder, Shell)
  from the status bar menu in Settings > General. Hidden launchables stay
  fully usable through their Option shortcuts.

## Removed

- **CPU-reactive lightning animation** — The status bar animation introduced
  in 1.2.0 has been removed. Any `statusBarAnimation` value left in existing
  config files is ignored safely.

## Notes

- macOS 14.0+ required. Chrome required for URL launch type.
