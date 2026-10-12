# Chap 2.8.1

## Changed

- **Quick Note opens under the notch** — Clicking the note icon now folds the
  dock and opens the note window attached just below the notch. Drag it anywhere
  after that; Chap remembers its size.

## Added

- **Quick Note backups** — Before saving over your note, Chap keeps the previous
  version (at most every 10 minutes, and right away if a long note suddenly loses
  most of its text). The newest ten stay in Application Support/Chap/QuickNote
  Backups; open the folder with Show Backups in the note window.

## Fixed

- **A note Chap can't read is never overwritten** — If the note file can't be
  read, Chap moves it into Backups instead of showing an empty note you could type
  over. If a save fails, the note says "Couldn't save".
