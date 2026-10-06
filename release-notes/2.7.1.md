# Chap 2.7.1

## Changed

- **Chap Drop remembers originals** — Dropping a file no longer copies it. Chap
  keeps a reference to the original: no extra space, it follows the file if you
  move or rename it, and lets it go if you delete it. Removing an item never
  deletes the original. Items from temporary places are still copied.
- **Focus ring** — Focus is one ring now. Press it to start (pick 1h, 4h, or 8h
  below); while it runs the ring empties with the time left. Hover for Chap off.
- **Quick Note saves when you click away** — The note saves the moment you click
  elsewhere, and shows "Saved" with the time in the corner.
- **Shelves stay on the left** — The first two notch slots are for Screenshots
  and Downloads, so a folded shelf always opens on the same side.

## Fixed

- **Settings survive a version mismatch** — Settings saved by a newer Chap no
  longer reset an older one. If a settings file ever can't be read, Chap keeps
  the original as `~/.chap.json.unreadable-<time>`.
