---
title: Dictation & multi-recording
description: The core dictation flow, recording modes, the non-stop multi-recording queue, shortcuts, and the URL scheme.
---

Dictation is Whispree's core flow. **Record → STT → (optional) AI correction → insert into the previously focused app** all chain together from a single shortcut.

## Basic flow

1. Start recording with the shortcut (`Ctrl+Shift+R`).
2. While you speak, the waveform overlay shows the state and the shortcut badges.
3. When you stop recording, STT transcribes; if a correction engine is on, it polishes the text, then
4. The result is inserted into the input field of **the app you were using right before you started recording** (clipboard + paste).

You don't need to pick a target app separately. Whispree remembers the app at the moment recording started and returns to that spot. If there's no valid target (e.g., recording from the Settings window), it falls back to a clipboard copy.

## Recording modes

Choose one in Settings → General.

| Mode | Behavior | Best for |
| --- | --- | --- |
| **Push-to-talk** *(default)* | Records while you hold the shortcut, transcribes when you release | Short, frequent utterances |
| **Toggle** | Press once to start, press again to stop | Long, continuous speech |

## Non-stop multi-recording

Whispree separates recording from post-processing. So you can **start the next recording right away while the previous utterance is still being transcribed and corrected**.

- When you stop recording, that utterance immediately enters the queue as a **job** (including a snapshot of settings, audio, target, and screenshots).
- STT and AI correction run in parallel within **each provider's concurrency limit**.
- The final **insertion always follows the order you spoke (FIFO)** — even if a later job finishes first, the order is preserved.
- Insertion is **paused while recording** and resumes from the front of the queue once recording ends.

The overlay/dashboard shows the state with quiet counts (waiting N · processing N).

:::tip
You don't have to sit and wait for dictation results. Keep speaking as thoughts come to you, and Whispree files them in, in order.
:::

## ESC — cancels scope only

ESC cancels **only the one job currently visible**. It doesn't wipe the entire queue being processed in the background at once. The cancellation scope depends on the situation, in order: preview → screen selection/insertion in progress → recording in progress → the waiting item shown on screen (`Cancel #N`).

## Control from outside (URL scheme)

You can control recording via URLs from Raycast, Stream Deck, Keyboard Maestro, AppleScript, and more.

| URL | Action |
| --- | --- |
| `whispree://toggle` | Toggle recording |
| `whispree://start` (or `whispree://push`) | Start recording |
| `whispree://stop` (or `whispree://release`) | End recording |

## Menu bar & overlay

- **Menu bar icon** — shows recording/waiting state; clicking it opens the main window.
- **Waveform overlay** — shows the recording/transcribing/correcting stage, the waveform, and shortcut badges like Stop · `Cancel esc` · `Img Attach ⌥`. You can turn it off with **Show overlay** in Settings → General.

For the full list of shortcuts, see [Shortcuts](/en/reference/shortcuts/); for the internal queue structure, see [Architecture at a glance](/en/reference/architecture/).
