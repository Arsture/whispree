# FreeWhisper v1.0 Work Plan

> Generated: 2026-02-21
> Status: Ready for implementation

---

## 1. Context

### 1.1 Original Request

Build a free, fully local macOS app (SuperWhisper alternative) for speech-to-text with LLM post-processing on Apple Silicon. The app should support customizable global hotkeys, push-to-talk and toggle recording modes, streaming transcription, and text insertion into any active application.

### 1.2 Interview Summary

| Decision | Choice |
|----------|--------|
| Architecture | Pure Swift (WhisperKit + mlx-swift-lm) |
| Recording Mode | Push-to-talk + Toggle mode (both) |
| LLM Post-processing | Toggle-able (user can enable/disable) |
| MVP Scope | Full feature set (hotkey, STT, LLM, text insertion, model download UI, settings, streaming) |
| Distribution | DMG for MVP, Sparkle auto-updates later |
| Target | macOS 14+ (Sonoma), Apple Silicon only |
| License | Open source, free |

### 1.3 Research Findings

- **WhisperKit**: Pure Swift, CoreML + ANE, ~0.5-1.0s latency, MIT license, SPM install
- **mlx-swift-lm**: Pure Swift, HuggingFace integration, `loadModel(id:)` + `ChatSession` API
- **Best STT model**: `large-v3-turbo` (~1.5GB) -- 99 languages including Korean
- **Best LLM model**: `Qwen2.5-3B-Instruct-4bit` (~2GB) -- 29+ languages, 50-70 tok/s on M2 Pro
- **KeyboardShortcuts**: macOS 10.15+, fully sandboxed, SwiftUI `Recorder` component
- **VoiceInk reference**: whisper.cpp based, uses KeyboardShortcuts + Sparkle + LaunchAtLogin

---

## 2. Work Objectives

### 2.1 Core Objective

Deliver a production-quality native macOS menu bar app that provides:
1. Global hotkey-triggered voice recording (push-to-talk and toggle modes)
2. Real-time streaming STT via WhisperKit
3. Optional LLM-based text correction via mlx-swift-lm
4. Automatic text insertion into the active application

### 2.2 Deliverables

1. Xcode project with clean architecture (MVVM + Services)
2. Functioning `.app` bundle
3. DMG installer
4. README with build instructions

### 2.3 Definition of Done

- [ ] App launches as menu bar icon on macOS 14+ Apple Silicon
- [ ] Global hotkey triggers recording (push-to-talk and toggle modes work)
- [ ] WhisperKit transcribes speech with streaming partial results displayed
- [ ] LLM correction can be toggled on/off and corrects Korean/English text
- [ ] Corrected text is inserted at cursor position in any app
- [ ] First-run experience downloads models with progress indication
- [ ] Settings UI allows hotkey customization and model selection
- [ ] End-to-end latency < 2.5 seconds for typical utterances (5-10s audio)
- [ ] Total memory usage < 6GB (WhisperKit + LLM + app overhead)

---

## 3. Guardrails

### 3.1 Must Have

- Pure Swift -- no Python runtime dependency
- Fully local -- zero network calls after model download
- macOS 14+ Apple Silicon only (no Intel support needed)
- Menu bar app (no Dock icon by default)
- Accessibility API for text insertion with clipboard fallback
- Model download progress visible to user

### 3.2 Must NOT Have

- Cloud API integration of any kind
- Intel/x86 support
- iOS/iPadOS support (macOS only for now)
- Custom model training or fine-tuning UI
- Audio file import (live microphone only for MVP)
- Multi-user or collaboration features

---

## 4. Architecture

### 4.1 High-Level Architecture Diagram

```
+------------------------------------------------------------------+
|                        FreeWhisper.app                            |
+------------------------------------------------------------------+
|                                                                   |
|  +--------------------+    +----------------------------------+   |
|  |   Presentation     |    |          App Services            |   |
|  |                    |    |                                  |   |
|  |  MenuBarView       |    |  AppState (ObservableObject)     |   |
|  |  TranscriptionView |    |    |                             |   |
|  |  SettingsView       |    |    +-- HotkeyManager            |   |
|  |  ModelDownloadView |    |    +-- RecordingCoordinator      |   |
|  |  OnboardingView    |    |    +-- TranscriptionCoordinator  |   |
|  +--------+-----------+    |    +-- TextInsertionService      |   |
|           |                |    +-- ModelManager               |   |
|           |  observes      |                                  |   |
|           +--------------->+----------------------------------+   |
|                                         |                         |
|                            uses         |                         |
|                    +--------------------+--------------------+    |
|                    |                    |                    |    |
|              +-----v------+     +------v-------+    +------v--+  |
|              |AudioService|     |  STTService   |    |LLMService| |
|              |            |     |               |    |          | |
|              |AVAudioEngine|    | WhisperKit    |    |mlx-swift | |
|              |16kHz mono  |     | Streaming API |    |  -lm     | |
|              +------------+     +---------------+    +----------+ |
|                                                                   |
+------------------------------------------------------------------+
                          |
          +---------------+----------------+
          |                                |
    +-----v------+                  +------v-------+
    |  macOS AX  |                  | HuggingFace  |
    |  API       |                  | Hub (models) |
    | (text      |                  | (one-time    |
    |  insertion)|                  |  download)   |
    +------------+                  +--------------+
```

### 4.2 Layer Responsibilities

| Layer | Responsibility | Key Types |
|-------|---------------|-----------|
| **Presentation** | SwiftUI views, user interaction | `MenuBarView`, `TranscriptionOverlayView`, `SettingsView`, `OnboardingView` |
| **App Services** | Coordination, state management | `AppState`, `HotkeyManager`, `RecordingCoordinator`, `TranscriptionCoordinator` |
| **Core Services** | Hardware/ML interaction | `AudioService`, `STTService`, `LLMService`, `TextInsertionService`, `ModelManager` |

### 4.3 Data Flow

```
User presses hotkey
       |
       v
HotkeyManager --> RecordingCoordinator.startRecording()
       |
       v
AudioService starts AVAudioEngine (16kHz, mono, Float32)
       |  audio buffers
       v
STTService (WhisperKit) processes audio
       |  streaming partial results
       v
TranscriptionCoordinator updates AppState.partialText
       |
       v  (on recording stop)
STTService returns final transcription
       |
       v
[if LLM enabled] LLMService corrects text
       |
       v
TextInsertionService inserts into active app
       |
       v
AppState.status = .idle
```

---

## 5. Tech Stack

### 5.1 Swift Packages

| Package | SPM URL | Version | Purpose |
|---------|---------|---------|---------|
| **WhisperKit** | `https://github.com/argmaxinc/WhisperKit` | >= 0.9.0 | STT engine (CoreML + ANE) |
| **mlx-swift-lm** | `https://github.com/ml-explore/mlx-swift-lm` | latest | LLM inference (MLX GPU) |
| **KeyboardShortcuts** | `https://github.com/sindresorhus/KeyboardShortcuts` | latest | Global hotkey registration |
| **Sparkle** | `https://github.com/sparkle-project/Sparkle` | >= 2.0 | Auto-updates (Phase 2) |
| **LaunchAtLogin** | `https://github.com/sindresorhus/LaunchAtLogin-Modern` | latest | Login item support |

### 5.2 System Frameworks

| Framework | Purpose |
|-----------|---------|
| `AVFoundation` / `AVAudioEngine` | Microphone capture |
| `ApplicationServices` (AX API) | Text insertion via accessibility |
| `AppKit` (`NSPasteboard`, `NSStatusItem`) | Clipboard fallback, menu bar |
| `SwiftUI` | All UI |
| `Combine` / `async-await` | Reactive data flow |
| `UserDefaults` / `@AppStorage` | Settings persistence |

### 5.3 Models (Auto-downloaded at first launch)

| Model | Size | Purpose | HuggingFace ID |
|-------|------|---------|----------------|
| WhisperKit large-v3-turbo | ~1.5 GB | STT | auto-selected by WhisperKit |
| Qwen2.5-3B-Instruct 4bit | ~2.0 GB | LLM correction | `mlx-community/Qwen2.5-3B-Instruct-4bit` |

---

## 6. Project Structure

```
FreeWhisper/
|-- FreeWhisper.xcodeproj/
|-- FreeWhisper/
|   |-- App/
|   |   |-- FreeWhisperApp.swift          # @main, NSApplicationDelegateAdaptor
|   |   |-- AppDelegate.swift             # NSStatusItem setup, menu bar
|   |   |-- AppState.swift                # Central ObservableObject
|   |   +-- Constants.swift               # App-wide constants
|   |
|   |-- Models/
|   |   |-- RecordingMode.swift           # .pushToTalk, .toggle
|   |   |-- TranscriptionState.swift      # .idle, .recording, .transcribing, .correcting
|   |   |-- AppSettings.swift             # UserDefaults-backed settings model
|   |   +-- ModelInfo.swift               # Model metadata (name, size, status)
|   |
|   |-- Services/
|   |   |-- Audio/
|   |   |   +-- AudioService.swift        # AVAudioEngine wrapper
|   |   |
|   |   |-- STT/
|   |   |   +-- STTService.swift          # WhisperKit wrapper with streaming
|   |   |
|   |   |-- LLM/
|   |   |   |-- LLMService.swift          # mlx-swift-lm wrapper
|   |   |   +-- CorrectionPrompts.swift   # System prompts for Korean/English
|   |   |
|   |   |-- TextInsertion/
|   |   |   +-- TextInsertionService.swift # AX API + clipboard fallback
|   |   |
|   |   |-- ModelManagement/
|   |   |   +-- ModelManager.swift        # Download, cache, status tracking
|   |   |
|   |   +-- Hotkey/
|   |       +-- HotkeyManager.swift       # KeyboardShortcuts integration
|   |
|   |-- Coordinators/
|   |   |-- RecordingCoordinator.swift    # Orchestrates record -> transcribe -> correct -> insert
|   |   +-- TranscriptionCoordinator.swift # Manages streaming state
|   |
|   |-- Views/
|   |   |-- MenuBar/
|   |   |   |-- MenuBarView.swift         # NSPopover content
|   |   |   +-- StatusItemController.swift # NSStatusItem management
|   |   |
|   |   |-- Transcription/
|   |   |   |-- TranscriptionOverlayView.swift  # Floating overlay showing partial results
|   |   |   +-- TranscriptionHistoryView.swift   # Past transcriptions list
|   |   |
|   |   |-- Settings/
|   |   |   |-- SettingsView.swift        # Main settings container
|   |   |   |-- GeneralSettingsView.swift # Hotkey, mode, launch at login
|   |   |   |-- ModelSettingsView.swift   # Model selection, download management
|   |   |   +-- LLMSettingsView.swift     # LLM toggle, prompt customization
|   |   |
|   |   +-- Onboarding/
|   |       |-- OnboardingView.swift      # First-run wizard
|   |       +-- ModelDownloadView.swift   # Download progress
|   |
|   |-- Resources/
|   |   |-- Assets.xcassets/              # App icon, menu bar icons
|   |   +-- Localizable.strings           # Korean + English strings
|   |
|   |-- Entitlements/
|   |   +-- FreeWhisper.entitlements      # Microphone, accessibility
|   |
|   +-- Info.plist
|
|-- FreeWhisperTests/
|   |-- Services/
|   |   |-- AudioServiceTests.swift
|   |   |-- STTServiceTests.swift
|   |   |-- LLMServiceTests.swift
|   |   +-- TextInsertionServiceTests.swift
|   +-- Coordinators/
|       +-- RecordingCoordinatorTests.swift
|
+-- README.md
```

---

## 7. Implementation Phases

### Phase 0: Project Scaffolding
**Goal**: Xcode project compiles and runs as an empty menu bar app.
**Estimated effort**: 1-2 hours

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 0.1 | Create Xcode project (macOS App, SwiftUI lifecycle) | Project created with bundle ID, deployment target macOS 14.0, Apple Silicon only |
| 0.2 | Configure as menu bar app (LSUIElement = true) | App shows in menu bar, not in Dock |
| 0.3 | Set up NSStatusItem with basic menu | Menu bar icon visible, click shows popover with "FreeWhisper" text |
| 0.4 | Add all SPM dependencies (WhisperKit, mlx-swift-lm, KeyboardShortcuts, LaunchAtLogin) | All packages resolve and project compiles |
| 0.5 | Create directory structure (App/, Models/, Services/, Views/, Coordinators/) | All directories created with placeholder files |
| 0.6 | Configure entitlements (microphone access, accessibility) | Entitlements file includes `com.apple.security.device.audio-input` |
| 0.7 | Create AppState.swift as central ObservableObject | AppState compiles with basic published properties |

**Commit**: `feat: scaffold FreeWhisper Xcode project with SPM dependencies and menu bar setup`

---

### Phase 1: Audio Recording Service
**Goal**: Record microphone audio and produce a usable audio buffer.
**Estimated effort**: 2-3 hours
**Depends on**: Phase 0

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 1.1 | Implement AudioService with AVAudioEngine | Captures 16kHz mono Float32 audio from default input device |
| 1.2 | Implement start/stop recording with audio buffer accumulation | `startRecording()` begins capture, `stopRecording()` returns accumulated `[Float]` buffer |
| 1.3 | Implement audio level monitoring (for UI feedback) | Publishes `currentLevel: Float` (0.0 - 1.0) via Combine |
| 1.4 | Handle microphone permissions gracefully | Requests permission on first use, shows alert if denied |
| 1.5 | Add recording state management | `isRecording` published property, proper cleanup on stop |
| 1.6 | Test with simple playback or file export | Can record 5s of audio and verify non-silent buffer |

**Commit**: `feat: implement AudioService with AVAudioEngine for 16kHz mono capture`

---

### Phase 2: WhisperKit STT Integration
**Goal**: Transcribe recorded audio to text using WhisperKit.
**Estimated effort**: 3-4 hours
**Depends on**: Phase 1

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 2.1 | Implement STTService wrapping WhisperKit | Initializes WhisperKit with configurable model selection |
| 2.2 | Implement basic (non-streaming) transcription | `transcribe(audioBuffer: [Float]) async -> String` returns recognized text |
| 2.3 | Implement streaming transcription with partial results | Publishes partial results as `AsyncStream<String>` during recording |
| 2.4 | Handle model loading states (not downloaded, downloading, ready) | Exposes `modelState` published property |
| 2.5 | Support language detection (auto) and forced language modes | Configuration option for auto-detect vs. forced Korean/English |
| 2.6 | Benchmark transcription latency | Log timing; target < 1.0s for 5-10s audio clips on M2 Pro |

**Commit**: `feat: integrate WhisperKit STT with streaming transcription support`

---

### Phase 3: Model Management
**Goal**: Download, cache, and manage ML models with progress UI.
**Estimated effort**: 3-4 hours
**Depends on**: Phase 2 (for WhisperKit model awareness)

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 3.1 | Implement ModelManager service | Tracks download state for WhisperKit and LLM models separately |
| 3.2 | Implement WhisperKit model download with progress | Uses WhisperKit built-in download; publishes progress (0.0-1.0) |
| 3.3 | Implement mlx-swift-lm model download with progress | Downloads from HuggingFace Hub; publishes progress |
| 3.4 | Implement model cache location management | Models stored in `~/Library/Application Support/FreeWhisper/Models/` |
| 3.5 | Implement model deletion and re-download | User can delete cached models to free disk space |
| 3.6 | Create OnboardingView with model download progress | First-run wizard: welcome -> microphone permission -> model download -> ready |
| 3.7 | Create ModelDownloadView (reusable progress component) | Shows model name, size, download progress bar, cancel button |

**Commit**: `feat: implement model management with download progress UI and onboarding flow`

---

### Phase 4: LLM Post-Processing
**Goal**: Correct transcribed text using local LLM.
**Estimated effort**: 3-4 hours
**Depends on**: Phase 3 (model management)

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 4.1 | Implement LLMService wrapping mlx-swift-lm | Loads Qwen2.5-3B-Instruct-4bit via `loadModel(id:)` |
| 4.2 | Implement text correction method | `correct(text: String) async -> String` returns corrected text |
| 4.3 | Create CorrectionPrompts with Korean/English system prompt | System prompt covers: spacing, punctuation, homophones, particles, G2P errors |
| 4.4 | Implement LLM toggle (on/off) | User preference persisted, coordinator skips LLM when off |
| 4.5 | Implement streaming LLM output (for UI feedback) | Shows correction progress in real-time |
| 4.6 | Add timeout and error handling | 5-second timeout; on failure, return original uncorrected text |
| 4.7 | Benchmark correction latency | Log timing; target < 1.5s for typical corrections on M2 Pro |

**LLM System Prompt**:
```
당신은 한국어/영어 이중 언어 텍스트 교정 보조입니다.
다음 STT 오류를 수정하세요: (1) 띄어쓰기, (2) 구두점,
(3) 동음이의어, (4) 조사 (은/는, 이/가, 을/를),
(5) G2P 맞춤법 오류. 의미를 바꾸지 마세요. 원래 언어를 유지하세요.
수정된 텍스트만 출력하세요.
```

**Commit**: `feat: integrate mlx-swift-lm for LLM-based text correction with toggle support`

---

### Phase 5: Global Hotkey and Recording Modes
**Goal**: Customizable global hotkey with push-to-talk and toggle modes.
**Estimated effort**: 2-3 hours
**Depends on**: Phase 1 (AudioService)

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 5.1 | Implement HotkeyManager using KeyboardShortcuts | Registers default hotkey (e.g., Option+Space) |
| 5.2 | Implement push-to-talk mode | Key down = start recording, key up = stop and transcribe |
| 5.3 | Implement toggle mode | First press = start, second press = stop and transcribe |
| 5.4 | Add recording mode selection in settings | User can switch between push-to-talk and toggle |
| 5.5 | Add hotkey customization UI using KeyboardShortcuts.Recorder | SwiftUI view for recording custom shortcuts |
| 5.6 | Visual feedback during recording | Menu bar icon changes state (idle/recording/processing) |

**Commit**: `feat: implement global hotkey with push-to-talk and toggle recording modes`

---

### Phase 6: Text Insertion
**Goal**: Insert corrected text into the active application at cursor position.
**Estimated effort**: 2-3 hours
**Depends on**: Phase 4

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 6.1 | Implement AX API text insertion (primary method) | Uses `AXUIElementCopyAttributeValue` to find focused text field and insert |
| 6.2 | Implement clipboard fallback (Cmd+V) | When AX fails, copies to pasteboard and simulates Cmd+V, then restores original clipboard |
| 6.3 | Add accessibility permission check and guidance | Detects if accessibility permission is granted; shows system preferences deep link if not |
| 6.4 | Handle edge cases (no focused text field, read-only fields) | Falls back to clipboard method gracefully |
| 6.5 | Test across common apps | Verify insertion works in: Notes, Safari, VSCode, Slack, Terminal |

**Commit**: `feat: implement text insertion via AX API with clipboard fallback`

---

### Phase 7: Recording Coordinator (Full Pipeline)
**Goal**: Wire everything together into the complete pipeline.
**Estimated effort**: 2-3 hours
**Depends on**: Phases 1-6

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 7.1 | Implement RecordingCoordinator | Orchestrates: hotkey -> record -> transcribe -> [correct] -> insert |
| 7.2 | Implement TranscriptionCoordinator for streaming state | Manages partial results display during recording |
| 7.3 | Wire AppState to all services | All state changes flow through AppState to UI |
| 7.4 | Implement state machine (idle -> recording -> transcribing -> correcting -> inserting -> idle) | Clean transitions, no invalid states |
| 7.5 | Add error recovery | Any service failure returns to idle with user-visible error message |
| 7.6 | End-to-end integration test | Record 5s audio -> get corrected text inserted into TextEdit |

**Commit**: `feat: wire full pipeline - record, transcribe, correct, insert`

---

### Phase 8: UI Polish
**Goal**: Complete, polished user interface.
**Estimated effort**: 3-4 hours
**Depends on**: Phase 7

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 8.1 | Design and implement MenuBarView popover | Shows: current status, recent transcription, quick settings |
| 8.2 | Implement TranscriptionOverlayView | Floating translucent overlay near cursor showing streaming text |
| 8.3 | Implement SettingsView (General tab) | Hotkey customization, recording mode, launch at login |
| 8.4 | Implement SettingsView (Models tab) | Model list with status, download/delete buttons, disk usage |
| 8.5 | Implement SettingsView (LLM tab) | LLM toggle, custom prompt editor, language preference |
| 8.6 | Implement TranscriptionHistoryView | Scrollable list of past transcriptions with copy button |
| 8.7 | Add audio level indicator during recording | Animated waveform or level bar in overlay |
| 8.8 | Add app icon and menu bar icon set | Professional icon for both light and dark mode |
| 8.9 | Localize strings (Korean + English) | All user-facing strings in Localizable.strings |

**Commit**: `feat: complete UI with settings, overlay, history, and localization`

---

### Phase 9: Testing and Optimization
**Goal**: Stable, performant app ready for distribution.
**Estimated effort**: 3-4 hours
**Depends on**: Phase 8

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 9.1 | Write unit tests for all services | AudioService, STTService, LLMService, TextInsertionService covered |
| 9.2 | Profile memory usage | Total < 6GB with both models loaded; no memory leaks |
| 9.3 | Profile and optimize latency | End-to-end < 2.5s for 5-10s audio; identify bottlenecks |
| 9.4 | Test model preloading strategy | Models stay warm in memory between transcriptions; lazy unload after 5min idle |
| 9.5 | Handle edge cases: empty audio, very long audio (>60s), rapid hotkey toggling | Graceful behavior in all cases |
| 9.6 | Test on clean macOS install | Verify first-run experience, permissions flow, model downloads |

**Commit**: `test: add unit tests and optimize memory/latency performance`

---

### Phase 10: Distribution
**Goal**: Distributable DMG.
**Estimated effort**: 2-3 hours
**Depends on**: Phase 9

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 10.1 | Configure code signing (Developer ID or ad-hoc for open source) | App is signed and passes `codesign --verify` |
| 10.2 | Create DMG build script | `make dmg` produces `FreeWhisper-v1.0.dmg` |
| 10.3 | Design DMG background (drag app to Applications) | Standard macOS DMG layout |
| 10.4 | Write README.md | Build instructions, requirements, usage guide |
| 10.5 | Set up GitHub repository | Clean repo with .gitignore, LICENSE (MIT), README |
| 10.6 | Test DMG install on clean system | Fresh install -> onboarding -> model download -> working transcription |

**Commit**: `chore: add DMG build pipeline and distribution setup`

---

## 8. Dependency Graph

```
Phase 0: Scaffolding
    |
    +---> Phase 1: Audio Recording
    |         |
    |         +---> Phase 2: WhisperKit STT
    |         |         |
    |         |         +---> Phase 3: Model Management
    |         |                   |
    |         |                   +---> Phase 4: LLM Post-Processing
    |         |                             |
    |         +---> Phase 5: Hotkeys        |
    |                   |                   |
    |                   +----> Phase 6: Text Insertion
    |                              |        |
    +------------------------------+--------+
                                   |
                             Phase 7: Full Pipeline
                                   |
                             Phase 8: UI Polish
                                   |
                             Phase 9: Testing
                                   |
                             Phase 10: Distribution
```

**Parallelizable**: Phases 5 (Hotkeys) can run in parallel with Phases 2-4.

---

## 9. Risks and Mitigations

### 9.1 Critical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|------------|------------|
| **WhisperKit streaming API limitations** | May not support real-time partial results as expected | Medium | WhisperKit does support streaming via `transcribe(audioArray:)` with callback. Fallback: use chunked transcription (process every 2s of audio) for pseudo-streaming. |
| **mlx-swift-lm model loading time** | First LLM call may be slow (model load ~5-10s) | High | Preload model at app launch; keep warm in memory. Show loading indicator on first use. |
| **AX API text insertion unreliable** | Some apps block AX insertion | Medium | Clipboard fallback (Cmd+V) as automatic secondary method. Document known incompatible apps. |
| **Memory pressure with both models** | WhisperKit (~1.5GB) + LLM (~2GB) + app = ~4GB on 16GB system | Low | Implement model unloading after idle timeout. Allow user to disable LLM entirely. Monitor memory pressure via `os_proc_available_memory()`. |
| **End-to-end latency exceeds 2.5s** | User experience degradation | Medium | Optimize: (a) keep models preloaded, (b) start LLM while STT finalizes last tokens, (c) use smaller LLM model option (Qwen2.5-1.5B), (d) make LLM correction async (insert raw first, replace with corrected). |

### 9.2 Technical Risks

| Risk | Mitigation |
|------|-----------|
| WhisperKit API breaking changes | Pin to specific version (>= 0.9.0). Follow argmaxinc releases. |
| mlx-swift-lm is relatively new | The library is maintained by Apple's ML Explore team. If issues arise, fall back to running mlx-lm via Process() as escape hatch. |
| macOS permission dialogs confuse users | Comprehensive onboarding flow with step-by-step permission guidance (microphone, accessibility). |
| KeyboardShortcuts conflicts with system shortcuts | Validate shortcut on registration; warn user of conflicts. Use non-conflicting defaults (Option+Space). |
| App notarization for Gatekeeper | Use `xcrun notarytool` for notarization. For open-source builds without Apple Developer account, provide build-from-source instructions. |

### 9.3 Fallback: LLM Latency Optimization Strategies

If LLM correction takes too long (>1.5s), apply these in order:

1. **Pipeline overlap**: Start LLM correction while WhisperKit is finalizing the last few tokens
2. **Optimistic insertion**: Insert raw STT text immediately, then replace with corrected text when ready
3. **Smaller model**: Offer `Qwen2.5-1.5B-Instruct-4bit` (~1GB) as a speed option
4. **Speculative correction**: Only run LLM when confidence is below a threshold (based on WhisperKit's token probabilities)

---

## 10. Commit Strategy

Each phase produces one atomic commit with a descriptive message:

| Phase | Commit Message |
|-------|---------------|
| 0 | `feat: scaffold FreeWhisper Xcode project with SPM dependencies and menu bar setup` |
| 1 | `feat: implement AudioService with AVAudioEngine for 16kHz mono capture` |
| 2 | `feat: integrate WhisperKit STT with streaming transcription support` |
| 3 | `feat: implement model management with download progress UI and onboarding flow` |
| 4 | `feat: integrate mlx-swift-lm for LLM-based text correction with toggle support` |
| 5 | `feat: implement global hotkey with push-to-talk and toggle recording modes` |
| 6 | `feat: implement text insertion via AX API with clipboard fallback` |
| 7 | `feat: wire full pipeline - record, transcribe, correct, insert` |
| 8 | `feat: complete UI with settings, overlay, history, and localization` |
| 9 | `test: add unit tests and optimize memory/latency performance` |
| 10 | `chore: add DMG build pipeline and distribution setup` |

Additional commits within phases are acceptable for meaningful sub-milestones.

---

## 11. Success Criteria

### Functional

- [ ] Press Option+Space -> speak -> release -> corrected text appears in active app
- [ ] Toggle mode works: press once to start, press again to stop
- [ ] Streaming partial results visible during recording
- [ ] LLM correction toggle works (on: corrected text, off: raw STT output)
- [ ] Settings persist across app restarts
- [ ] Models download successfully on first launch

### Performance

- [ ] STT latency < 1.0s for 5-10s audio clips
- [ ] LLM correction < 1.5s for typical utterances
- [ ] End-to-end < 2.5s (hotkey release to text insertion)
- [ ] App memory < 6GB with both models loaded
- [ ] App launch to ready < 3s (models pre-cached)

### Quality

- [ ] Korean transcription accuracy: CER < 15% on conversational speech
- [ ] LLM correction improves CER by at least 30% relative
- [ ] No crashes during 1-hour continuous usage session
- [ ] Clean first-run experience on fresh macOS 14 install

---

## 12. Future Enhancements (Post-MVP)

Not in scope for v1.0, but worth tracking:

- Sparkle auto-update integration
- App Store distribution (requires sandboxing audit)
- Custom fine-tuned Korean Whisper model (e.g., seastar105/Korean-Whisper)
- App-specific LLM prompts (e.g., code dictation mode for VSCode)
- Audio file import/export
- Whisper model size options (tiny, base, small for faster but less accurate)
- Qwen3-4B upgrade when mlx-swift-lm supports it
- History search and export
- iCloud sync for settings
- Dictation commands ("new line", "period", "select all")
