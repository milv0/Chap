# Chap 1.1.13

## Improved

- **Launcher maintainability** — The URL and App launch pipelines were
  restructured into clear phases (baseline, launch, observe, report) with no
  behavior changes; window targeting, timing, and diagnostics are identical.
- **Leaner internals** — Removed dead code, unified duplicated Accessibility
  readback helpers, and switched domain validation to a compile-time-checked
  pattern.
- **Settings code organization** — The General tab moved to its own view file;
  appearance and behavior are unchanged.

## Notes

- No user-facing behavior changes in this release.
- Debug builds now automatically prune resize diagnostics older than 14 days.
- macOS 14.0+ required. Chrome required for URL launch type.
