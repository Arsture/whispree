---
title: Shortcuts
description: Whispree's full keyboard shortcuts and whether they can be remapped.
---

Global shortcuts are intercepted before system shortcuts (CGEventTap). Remappable shortcuts can be changed under **Settings → General → Shortcuts**.

## Global shortcuts

| Action | Default combo | Remap |
| --- | --- | --- |
| **Start/stop recording** (toggle or push-to-talk) | `Ctrl+Shift+R` | Yes |
| **Quick Fix** (instant correction of selected text) | `Ctrl+Shift+D` | Yes |
| **Toggle screenshot attach** (during recording) | hold left `⌥` ~0.5s | No (fixed) |
| **Cancel current scope** | `Esc` | No (fixed) |

:::tip
A shortcut can be assigned with **just a single modifier key** (e.g. right `⌥` alone). If the combo you pick conflicts with a known system shortcut, a warning is shown.
:::

## Screenshot selection panel

While the screenshot selection panel is open:

| Key | Action |
| --- | --- |
| `↑` `↓` | Move between items |
| `Space` | Select/deselect |
| `Enter` | Confirm |
| `⌘Enter` | Preview (Quick Look) |
| `Esc` | Skip |

## Quick Fix panel

| Key | Action |
| --- | --- |
| `Enter` | Save and replace |
| `Esc` | Cancel |

## External automation (URL scheme)

You can also control recording via URLs instead of shortcuts — Raycast, Stream Deck, Keyboard Maestro, etc.

| URL | Action |
| --- | --- |
| `whispree://toggle` | Toggle recording |
| `whispree://start` / `whispree://push` | Start recording |
| `whispree://stop` / `whispree://release` | Stop recording |
