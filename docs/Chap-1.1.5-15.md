# Chap 1.1.5

## Fixed

- URL window reuse now remembers only the Chrome app window created by that
  launchable after reuse is enabled.
- Existing user tabs, focused windows, and frontmost Chrome windows are no
  longer searched or selected as reuse targets.
- Closing the managed window, restarting Chrome, disabling reuse, or changing
  the URL safely clears the tracked window.
