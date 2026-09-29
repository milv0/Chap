# Chap Color System

This document records the colors used by the macOS app and their website
counterparts. App source remains authoritative.

## Fixed App Colors

| Token | Value | Source | Use |
|---|---:|---|---|
| Accent | `#3664FF` | `DS.accent` | Selection, primary actions, active controls |
| Accent soft | `rgba(54, 100, 255, 0.08)` | `DS.accentSoft` | Selected and hover backgrounds |
| Accent surface | `rgba(54, 100, 255, 0.12)` | `DS.accentSurface` | Emphasized fields and soft feature surfaces |
| Accent light | `#89A3FF` | `DS.accentLight` | Notch section icons on dark surfaces (dark Glass/Custom) |
| Danger | `#EB4444` | `DS.danger` | Destructive and error states |
| On-accent text | `#FFFFFF` | Primary button styling | Text and symbols on the accent color |

## Notch icons

Notch icons carry a soft brand blue so Chap feels like one product without the
blue competing with content. Titles and labels stay neutral gray.

| Where | Color | Source |
|---|---|---|
| Section title icons on dark backgrounds | `#89A3FF` at 90% | `DS.notchIconColor(onDarkBackground: true)` |
| Section title icons on light backgrounds | `#3664FF` at 75% | `DS.notchIconColor(onDarkBackground: false)` |
| Black top strip widgets (Drop box, Mirror, Quick Note) | White at 85%, 100% on hover | `DS.notchStripIconColor` |
| Active strip tool, Focus bolt when running | `#3664FF` | `DS.accent` |

## Notch panel presets

Custom style offers two one-click panel colors; the color picker covers the rest.

| Preset | Hex | Notes |
|---|---|---|
| Black | `#000000` | Extends the hardware notch (default) |
| Mist | `#E8ECF8` | Soft blue-gray light; light-background text and icon contrast applies |

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

The Chap 2 website uses a hardware-native dark stage rather than the previous
light settings-window composition. It keeps the same fixed Chap accent and uses
an ice-neutral contrast layer for the Mac display and trust sections.

| CSS token | Value |
|---|---:|
| `--blue` | `#3664FF` |
| `--blue-deep` | `#244CDC` |
| `--blue-light` | `#89A3FF` |
| `--ice` | `#DFE6FF` |
| `--night` | `#05070B` |
| `--night-soft` | `#0B0E15` |
| `--panel` | `#11151E` |
| `--panel-light` | `#181E2A` |
| `--ink` | `#F7F8FC` |
| `--muted` | `#9EA7B7` |
| `--muted-strong` | `#C5CAD4` |
| `--paper` | `#EEF1F7` |
| `--paper-ink` | `#141722` |
| `--paper-muted` | `#60697A` |
| `--line` | `rgba(255, 255, 255, 0.11)` |
| `--line-strong` | `rgba(255, 255, 255, 0.20)` |

The guided-tour coachmark tip and the `nudge` pulse reuse the fixed Chap
accent (`--blue` / `#3664FF`) rather than a dedicated token.

The interactive hero is a CSS-rendered Mac display and notch dock; it uses no
product screenshot or user data. Dark sections make the hardware notch the
visual anchor, while light Chap Drop and trust sections create contrast without
changing the app's `#3664FF` brand color.
