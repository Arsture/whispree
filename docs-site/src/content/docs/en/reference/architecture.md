---
title: Architecture at a glance
description: A light overview of how Whispree splits recording, processing, and insertion.
---

The detailed internals live in the repository's code and `AGENTS.md`. Here we explain just enough to understand "why you can dictate without stopping".

## Pipeline

```text
Hotkey
  → Audio recording (+ waveform FFT)
  → [Visual context capture] (when a vision model is active)
  → Enqueue dictation job (settings · audio · target · screenshot snapshot)
  → STT transcription   (parallel within per-provider concurrency limits)
  → [AI correction]      (parallel within per-provider concurrency limits)
  → FIFO insertion      (restore target context, then insert text/images)
```

The key is the **separation of recording, processing, and insertion**. That way, even if transcription/correction is slower than speech, recording can immediately move on to the next.

## Three design principles

- **Recording never blocks.** Speech goes straight into the queue, and STT/correction is processed in parallel behind the scenes.
- **Insertion keeps order (FIFO).** Even if a later job finishes first, insertion is serialized in the order you spoke. Insertion is paused while recording.
- **Cancellation keeps scope.** ESC cancels only the one job currently visible; it does not wipe the entire background queue.

## Where it goes back to

Each recording also remembers "where the result should go". It distinguishes regular apps, Chrome tabs, and iTerm2/tmux sessions, then at insertion time restores **the captured target context — not whatever app is frontmost now**. For Chrome, if the same input element is still active, Whispree re-reads the latest caret position changed during processing. (See [Context restore](/en/features/context/).)

## Safety constraints

- STT inference runs in the background so it doesn't block the UI.
- Text/image insertion is serialized — pasting at the same time would tangle focus and the clipboard.
- AI correction has a hallucination guard, so if a correction strays too far from the original, the original is left as-is.
