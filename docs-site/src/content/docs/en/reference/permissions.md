---
title: Permissions
description: The macOS permissions Whispree requests and which feature each one is used for.
---

Because Whispree records your voice, looks at your screen, and inserts text into other apps, it needs a few macOS privacy permissions. **Basic dictation works fully with just Microphone and Accessibility**; the rest are only needed when you use the corresponding feature.

## Permissions at a glance

| Permission | Used for | Symptom if missing |
| --- | --- | --- |
| **Microphone** | Voice recording (STT) | No sound captured during recording |
| **Accessibility** | Pasting the result into the previous app (sending key events) | Only clipboard copy works; auto-insert silently fails |
| **Screen Recording** | Screenshot capture for [Visual Context](/en/features/context/) | Screenshots are not included in vision correction |
| **Automation** | [Browser/terminal restore](/en/features/context/) (AppleScript) | Only Chrome/iTerm2 context capture/restore fails |
| **App Management** | Auto-update (optional) | Auto-update application is limited |

## How to grant

For most, **macOS prompts automatically the first time you use** the feature. To enable manually, allow Whispree per item under **System Settings → Privacy & Security**. The app's Settings → General (and the first-run onboarding) also has a permission status panel and shortcuts to System Settings.

Automation is granted **per target app** — e.g. Apple Music, Spotify, Google Chrome, iTerm2. It's requested the first time you use each feature.

:::caution
**Automation pitfall**: Browser/terminal restore can silently fail. The AppleScript permission prompt may not appear if the permission was never granted, leaving only a failure. Check that the target apps (Chrome/iTerm, etc.) under Whispree are enabled in System Settings → Privacy & Security → Automation.
:::

## Permission-to-feature mapping

- Basic dictation/insertion → **Microphone + Accessibility**
- Visual context (vision correction) → **Screen Recording**
- Browser/terminal restore → **Automation** (per target app)
- Pause music while recording → **Automation** when controlling music apps (Apple Music/Spotify)

For detailed per-feature behavior, see each [feature](/en/features/dictation/) doc.
