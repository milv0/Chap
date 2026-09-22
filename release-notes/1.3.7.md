# Chap 1.3.7

## Added

- **Keep Awake quit confirmation** — When a Keep Awake session is active,
  quitting Chap now requires an explicit "Quit Anyway" choice. Cancel is the
  default, preventing an accidental quit from ending the session.

## Improved

- **AX readback safety** — Window position and size readback now uses typed
  Accessibility values, eliminating an unsafe generic pointer conversion and
  its Release compiler warning.
- **Settings consistency** — Manual validation now includes hidden menu
  sections, and the settings close flow is simpler while preserving the same
  unsaved-change protection.
- **Current documentation** — Updated architecture, distribution, menu,
  Sparkle, Keep Awake, and historical attribution guidance.

## Notes

- Keep Awake remains session-only. Choosing Quit Anyway releases the power
  assertion before Chap exits; crashes and forced termination remain safely
  handled by macOS.
- macOS 14.0+ required. Chrome required for URL launch type.
