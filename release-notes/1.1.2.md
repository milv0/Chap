## Fixed

- **Reliable URL window reuse** — Chap now controls Chrome directly through its
  own Automation permission instead of a helper process.
- **Remembered Chrome windows** — After opening a URL window, Chap remembers
  that Chrome window for the current session and reuses it even after a login
  redirect changes the URL.
- **Stale-window recovery** — Closed windows and Chrome restarts automatically
  fall back to URL matching or opening a new window.

## Notes

- The first URL reuse may prompt for permission to let Chap control Google Chrome.
- macOS 14.0+ required. Chrome required for URL launch type.
