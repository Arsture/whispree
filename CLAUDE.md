# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Generate Xcode project (required after changing project.yml or adding/removing files)
xcodegen generate

# Build
xcodebuild -project NotMyWhisper.xcodeproj -scheme NotMyWhisper -destination 'platform=macOS,arch=arm64' build

# Run all tests (48 tests, includes E2E with real WhisperKit model loading ~24s first run)
xcodebuild -project NotMyWhisper.xcodeproj -scheme NotMyWhisper -destination 'platform=macOS,arch=arm64' test

# Deploy to /Applications
cp -R "$(find ~/Library/Developer/Xcode/DerivedData/NotMyWhisper-*/Build/Products/Debug -name 'NotMyWhisper.app' -maxdepth 1)" /Applications/
```

Metal Toolchain may be needed: `xcodebuild -downloadComponent MetalToolchain`

## What This Is

macOS menu bar STT app. Record speech → WhisperKit transcribe → LLM correct → paste into previous app. Runs locally on Apple Silicon (macOS 14+, arm64 only). XcodeGen (`project.yml`) generates the `.xcodeproj`.

## Architecture

**Pipeline flow** (orchestrated by `RecordingCoordinator`):
```
Hotkey → AudioService (record + FFT) → STTProvider.transcribe() → LLMProvider.correct() → TextInsertionService.insertText()
```

**Central state**: `AppState` (@MainActor ObservableObject) — holds transcription state, providers, settings, audio levels, history. All Views observe this.

**Provider abstraction**: Both STT and LLM use protocol-based providers switchable at runtime via `AppState.switchSTTProvider(to:)` / `switchLLMProvider(to:)`.

### STT Providers (`protocol STTProvider` — NOT @MainActor, runs off main thread)
- `WhisperKitProvider` — local CoreML+ANE, `whisper-large-v3-turbo`. Supports domain word → promptTokens injection
- `GroqSTTProvider` — Groq Cloud API, same model but server-side. Converts [Float] → WAV → multipart upload
- `LightningWhisperProvider` — Python FastAPI backend (`stt-engine/`), lightning-whisper-mlx

### LLM Providers (`@MainActor protocol LLMProvider`)
- `NoneProvider` — passthrough, no correction
- `LocalLLMProvider` — Qwen3-4B via mlx-swift-lm, 5s timeout, word-edit-distance safety (0.5 threshold)
- `OpenAIProvider` — ChatGPT Responses API with SSE streaming, reuses `~/.codex/auth.json` tokens via `CodexAuthService`

### Text Insertion
`TextInsertionService.insertText()` is async. Activates previous app → clipboard + CGEvent Cmd+V. Falls back to clipboard-only when no valid target app (e.g., recording from Settings window). Requires Accessibility permission (`AXIsProcessTrusted`).

## Key Design Decisions

- **STTProvider is NOT @MainActor** — ML inference must run off main thread to avoid MainActor deadlock. WhisperKit/Groq providers are `@unchecked Sendable`.
- **LLMProvider IS @MainActor** — LLM calls are lighter and need AppState access.
- **TextInsertionService uses `Task.sleep` not `Thread.sleep`** — yields MainActor during waits.
- **`RecordingCoordinator.startRecording()`** force-resets stuck states (transcribing/correcting/inserting) from previous failed pipelines.
- **`lastExternalApp`** tracked via `NSWorkspace.didActivateApplicationNotification` — captures the app before NotMyWhisper to avoid pasting into NotMyWhisper itself.
- **Word-edit-distance safety** in `LLMService`: word-based Levenshtein, threshold 0.5. Prevents LLM hallucination from replacing the entire text.
- **CorrectionPrompts** are in Korean with few-shot examples. `codeSwitchPrompt` handles Korean-English codeswitching (밸리데이션 → validation). `promptEngineeringPrompt` includes STT correction as step 1 then restructures spoken prompts.

## Settings Persistence

`AppSettings` (Codable) saved to UserDefaults key `"NotMyWhisperSettings"`. Key fields: `sttProviderType`, `llmProviderType`, `groqApiKey`, `openaiModel`, `correctionMode`, `domainWordSets`, `language`.

## SPM Dependencies

- WhisperKit 0.9.0 — STT (CoreML + Neural Engine)
- mlx-swift-lm (main branch) — local LLM inference (MLXLLM, MLXLMCommon)
- KeyboardShortcuts 2.0.0+ — global hotkey
- LaunchAtLogin 1.0.0+ — login item

## Audio & Visualization

`AudioService` captures at native sample rate, resamples to 16kHz mono for STT. Also computes 64-band FFT (Accelerate vDSP, voice-focused 80-3500Hz range) published as `frequencyBands` for the waveform view. `NeonWaveformView` renders slim rounded bars at 60fps with fast attack / slow decay smoothing.

## Concurrency Notes

- `AppState`, `RecordingCoordinator`, `AudioService`, `AppDelegate` — all `@MainActor`
- `WhisperKitProvider`, `LightningWhisperProvider`, `GroqSTTProvider` — nonisolated (NOT @MainActor), `@unchecked Sendable`
- Audio tap callback runs on audio thread; dispatches to MainActor via `Task { @MainActor in ... }`
- `processPipeline()` runs in a `Task` on MainActor; `await sttProvider.transcribe()` suspends MainActor and runs inference on background executor
