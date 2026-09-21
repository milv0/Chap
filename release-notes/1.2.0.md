# Chap 1.2.0

## Added

- **CPU-reactive lightning icon** — The Lightning status bar icon can now
  animate with your Mac's CPU load, RunCat-style: calm when idle, fast under
  load. Choose between two styles in Settings > General > Appearance:
  - **Pulse** — the bolt throbs between bright and dim.
  - **Wobble** — the bolt tilts side to side.
- **Fully optional monitoring** — CPU sampling runs only while an animation
  style is selected; choosing Off stops all monitoring. The setting applies
  to the Lightning icon.

## Changed

- **Product page** — The website is now English-only.

## Notes

- Animation speed follows CPU usage (about 1 frame/s when idle up to
  20 frames/s under full load), sampled every 3 seconds.
- macOS 14.0+ required. Chrome required for URL launch type.
