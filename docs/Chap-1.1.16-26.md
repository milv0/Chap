# Chap 1.1.16

## Fixed

- **More reliable URL window reuse** — When reusing a Chap-created Chrome
  window, a brief automation hiccup no longer falls back immediately to the
  slower new-window path. Chap now retries the window lookup once after a
  short delay, so the first shortcut press reuses the window as expected.
  Automation permission denials still fall back right away.

## Improved

- **Clearer reuse diagnostics** — When reuse is unavailable, the underlying
  automation error is now recorded in the system log for troubleshooting.

## Notes

- macOS 14.0+ required. Chrome required for URL launch type.
