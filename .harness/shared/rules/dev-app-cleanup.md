# Dev app cleanup

Only `/Applications/Chap.app` should exist when a task ends.

- Builds, tests, and the notch render tool create a Debug `Chap.app` in
  DerivedData; releases leave `Chap.xcarchive`, `export/`, and `dmg-root/` in
  `build/release/`.
- Every copy reads and writes the same `~/.chap.json`. A Debug build can save a
  value the installed version cannot read yet (2.7.0: the `seal` menu bar icon
  reset a 2.6.0 user's settings), so stray copies are a data risk, not just clutter.
- At the end of every task (after the last build, test, or render), run:

  ```bash
  Scripts/clean-dev-apps.sh          # --dry-run to preview
  ```

  It quits any running dev copy, unregisters it from LaunchServices, and deletes
  it. Installers (`*.pkg`, `*.dmg`) and `/Applications/Chap.app` are kept.
- If you relaunched a Debug build for the user to try, say so, and clean it up
  once they are done with it.
