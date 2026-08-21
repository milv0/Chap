## Fixed

- **Reliable existing URL window reuse** — Chap now searches every tab in every
  Chrome window before opening a new URL window.
- **Trailing-slash URL matching** — URLs such as `/Chap` and `/Chap/` are treated
  as the same target when reusing a Chrome window.
- **Focused-window placement** — Chap waits for the matched Chrome window to
  become focused before applying the configured position and size.

## Notes

- URL window reuse still requires macOS Accessibility permission for resizing.
- macOS may request permission to control Google Chrome when URL window reuse
  is first used.
- macOS 14.0+ required. Chrome required for URL launch type.
