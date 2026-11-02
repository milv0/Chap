# Chap 2.19.5

## Fixed

- **External-drive files stay in Chap Drop** — Ejecting a drive now hides its
  items instead of forgetting them. Reconnect the drive and they return.
- **Status updates stay in step** — Timer, Keep Awake, Cover Screens, and layout
  changes no longer replace the status menu while it is open.

## Changed

- **App launches keep the UI responsive** — Chap now checks existing app windows
  away from the main thread before opening and positioning a new one.
- **Lighter shelf refreshes** — Screenshots and Downloads share one refresh
  cycle while the notch is open, avoiding duplicate folder scans.
- **Less work behind the scenes** — Unchanged shortcuts are no longer
  re-registered, and notch window helpers now share one implementation.

## Testing

- Quick Note and Cover Screens window tests no longer touch your note, saved
  window size, displays, or power state.
