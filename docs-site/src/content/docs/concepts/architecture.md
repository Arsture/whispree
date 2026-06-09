---
title: Architecture
description: The recording, processing, and insertion pipeline.
---

Whispree separates capture, processing, and delivery so recording stays responsive even when transcription or correction is slower than speech.

## Pipeline

```text
Hotkey
  → AudioService records speech and FFT state
  → optional ContinuousScreenCaptureService captures visual context
  → DictationQueueState enqueues a job snapshot
  → STT provider transcribes under provider concurrency limits
  → LLM provider corrects under provider concurrency limits
  → FIFO delivery restores target context and inserts text/images
```

## Central actors

- `AppState` is the main SwiftUI-observed state surface.
- `RecordingCoordinator` owns active recording, job queue orchestration, and delivery.
- `DictationQueueState` owns per-job truth, provider concurrency, status transitions, and FIFO delivery gates.
- `TextInsertionService` serializes actual pasteboard/CGEvent insertion into the captured target.

## Target context

A recording captures where text should return. Whispree can distinguish generic apps, Chrome tabs, and iTerm2/tmux sessions. Delivery restores the captured context before insertion, rather than pasting into whichever app is currently frontmost.

## Safety constraints

- STT providers are not `@MainActor`; ML transcription must not block UI.
- LLM providers are `@MainActor` because they integrate with app state and provider UX.
- Text/image insertion is serialized; concurrent paste operations would corrupt target focus and pasteboard semantics.
- ESC is scoped. It can cancel preview, current recording, active delivery, or a foreground item, but must not wipe the whole background queue.
