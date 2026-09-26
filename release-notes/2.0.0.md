# Chap 2.0.0

Chap 2 turns the MacBook notch into an optional command surface while keeping
the classic status menu and Option shortcuts available everywhere.

## Added

- **Notch Launcher** — Hover the hardware notch to open a four-slot launcher.
  Arrange Sites, Apps, Folders, Scripts, or recent Screenshots in Settings →
  Notch using drag and drop, context menus, or VoiceOver actions.
- **Chap Drop** — Drag files to the notch or its count badge. The main dock
  becomes a translucent Drop here surface, keeps local copies in Chap's private
  Application Support folder, and presents them in a Finder-style file row for
  opening, dragging out, or removing.
- **Liquid Glass** — On macOS 26+, choose Apple Clear or Regular Liquid Glass
  with System, Light, or Dark appearance. Light pairs with Clear and Dark with
  Regular. Custom color and opacity remain available on macOS 14+.
- **Screenshot Shelf** — Show the newest screenshots in a notch slot without
  moving or duplicating their originals.
- **Live Keep Awake status** — An open notch dock shows the active session as a
  blue coffee icon with an `h:mm:ss` countdown.

## Changed

- **Focused launcher lists** — URL, App, Finder, and Shell now allow up to four
  launchables each, keeping the status menu and notch slots predictable.
- **Dedicated Notch settings** — Notch controls have their own Settings tab,
  including widget assignment, Custom appearance, and Glass material/appearance
  previews.
- **Complete configuration export** — Export now preserves hidden-menu and
  notch settings; import keeps the destination Mac's device-specific notch
  choices.
- **New public website** — The Chap site has been rebuilt around the notch,
  Chap Drop, Liquid Glass, Keep Awake, and the four launcher types.

## Reliability and Accessibility

- Repositions or removes notch surfaces when display resolution, arrangement,
  external displays, or clamshell state changes.
- Moves Drop copies, folder scans, and thumbnail decoding off the main thread;
  reports copy/remove failures and caches modification-aware thumbnails.
- Supports keyboard and VoiceOver alternatives for widget assignment and Drop
  file actions, adaptive foreground contrast, semantic Glass text, and reduced
  motion on the website.
- Preserves the existing status menu as the fallback on notchless Macs and when
  the Notch Launcher is disabled.

## Notes

- macOS 14.0+ is required.
- A MacBook notch is optional; all classic launch functionality works without
  one.
- Liquid Glass requires macOS 26+; Custom appearance supports macOS 14+.
- Google Chrome is required only for URL launchables.
