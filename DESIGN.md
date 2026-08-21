# Chap Color System

This document records the colors used by the macOS app and their website
counterparts. App source remains authoritative.

## Fixed App Colors

| Token | Value | Source | Use |
|---|---:|---|---|
| Accent | `#3664FF` | `DS.accent` | Selection, primary actions, active controls |
| Accent soft | `rgba(54, 100, 255, 0.08)` | `DS.accentSoft` | Selected and hover backgrounds |
| Accent surface | `#EBF0FF` | `DS.accentSurface` | Emphasized fields and soft feature surfaces |
| Danger | `#EB4444` | `DS.danger` | Destructive and error states |
| On-accent text | `#FFFFFF` | Primary button styling | Text and symbols on the accent color |

## Guide Window

`GuideWindow` follows the user's current macOS accent color, so it does not
have one fixed HEX value.

| Layer | App value | Website fallback |
|---|---|---|
| Border | `NSColor.controlAccentColor` at 60% | `rgba(54, 100, 255, 0.60)` |
| Fill | `NSColor.controlAccentColor` at 5% | `rgba(54, 100, 255, 0.05)` |

The website fallback uses Chap's fixed `#3664FF` accent because a web page
cannot read the user's macOS accent setting.

## Dynamic macOS Colors

These colors intentionally have no fixed HEX value. AppKit resolves them for
the active appearance, contrast settings, and macOS version.

| App token | AppKit source | Use |
|---|---|---|
| `DS.surfaceBg` | `NSColor.windowBackgroundColor` | Window and form background |
| `DS.cardBg` | `NSColor.controlBackgroundColor` | Cards and grouped controls |
| `DS.textPrimary` | `NSColor.labelColor` | Primary text |
| `DS.textSecondary` | `NSColor.secondaryLabelColor` | Supporting text |
| `DS.textTertiary` | `NSColor.tertiaryLabelColor` | Low-emphasis text |
| `DS.border` | `NSColor.separatorColor` | Dividers and control outlines |
| Warning | SwiftUI `.orange` | Display migration warnings |

Do not replace these semantic colors with sampled HEX values in the app.

## Website Mapping

The website uses a light macOS-style neutral base with Chap accent surfaces:

| CSS token | Value |
|---|---:|
| `--accent` | `#3664FF` |
| `--accent-dark` | `#244CDC` |
| `--accent-surface` | `#EBF0FF` |
| `--guide-fill` | `rgba(54, 100, 255, 0.05)` |
| `--guide-border` | `rgba(54, 100, 255, 0.60)` |
| `--surface` | `#F5F5F7` |
| `--card` | `#FFFFFF` |
| `--text` | `#1D1D1F` |
| `--text-secondary` | `#6E6E73` |
| `--separator` | `#D9D9DE` |

The neutral surface and card values are stable web approximations, not
replacements for AppKit semantic colors.
