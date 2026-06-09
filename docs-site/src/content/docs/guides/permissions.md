---
title: Permissions
description: macOS permissions required by Whispree.
---

Whispree depends on macOS privacy gates because it records audio, observes context, captures screenshots, and inserts text into other apps.

## Required permissions

| Permission | Why Whispree needs it | Failure symptom |
| --- | --- | --- |
| Microphone | Record speech for STT | Recording does not capture audio. |
| Accessibility | Send paste/keyboard events into the previous app | Text is copied but not inserted, or insertion silently fails. |
| Screen Recording | Capture window screenshots for VLM context | Visual correction lacks screenshots. |
| Automation | Use AppleScript for browser/terminal context capture and restore | Chrome/iTerm context capture or restore fails. |

## Automation gotcha

AppleScript execution must happen on the MainActor/main thread so TCC prompts can appear. Background AppleScript calls can fail with `-1743` without showing a prompt.

## Verification checklist

- Start recording from a non-Whispree target app.
- Stop recording and confirm text appears in the original target.
- Enable visual context and confirm screenshot selection appears when expected.
- Test browser or terminal context only after Automation permission is granted.
