# Chap 1.3.8

## Added

- **Safe Quit** — Quitting Chap now always asks for confirmation, with Cancel
  as the default. Confirmed quits release any active Keep Awake session before
  Chap exits.
- **Keep Awake status indicator** — Active Keep Awake sessions now turn both
  Default and Lightning status bar icons Chap blue, returning them to their
  normal system appearance when the session ends or expires.

## Improved

- **Accessibility readback safety** — Window position and size readback now
  uses typed Accessibility values, removing a Release compiler warning.
- **Current docs and settings validation** — Refreshed architecture and user
  guidance, removed dead homepage Korean styling, and aligned manual settings
  validation with hidden menu sections.

## Notes

- macOS 14.0+ required. Chrome required for URL launch type.
