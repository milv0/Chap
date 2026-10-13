# Chap 2.13.4

## Changed

- **Workspaces title opens Settings** — Click the Workspaces title in the notch,
  like the Sites, Apps, and Finder titles, to edit your workspaces in
  Settings → Launchers.
- **Progress while a workspace opens** — The notch row and the Open and Update
  Positions buttons show a spinner while Chap places windows, and only one
  workspace opens at a time.
- **Minimized windows come back** — Opening a workspace brings a minimized
  window out of the Dock and places it.
- **Keyboard** — The display menus and capture rows take focus; ↑↓ in the
  Settings sidebar moves through Workspaces too.

## Fixed

- **Alerts stayed hidden** — Messages about a workspace that could not be fully
  placed opened behind the apps Chap had just brought forward. They now come to
  the front and name the apps Chap couldn't place.
- **Update Positions** no longer reports success when saving failed, and keeps a
  window set to Follow Cursor on Follow Cursor.
- **Windows stay on screen** — A window saved smaller than its app allows is
  grown to the app's minimum size without being pushed off the display.
- **Capture Workspace re-reads the screen** when you choose it while the window
  is already open, and skips hidden (⌘H) apps.
- **Display lists follow your monitors** — Plugging in or unplugging a display
  updates the menus in Settings and Capture Workspace.
- **Removing a workspace in Settings** selects the next one instead of leaving
  the page empty.
