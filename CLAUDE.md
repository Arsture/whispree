# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 필수 규칙: 빌드 & 배포 & 커밋

하나의 feature/fix가 완료되면 반드시 다음을 수행:

1. 기존 앱 종료: `pkill -f "Whispree.app"`
2. 빌드: `xcodebuild -project Whispree.xcodeproj -scheme Whispree -destination 'platform=macOS,arch=arm64' build`
3. /Applications로 복사: `cp -R "$(find ~/Library/Developer/Xcode/DerivedData/Whispree-*/Build/Products/Debug -name 'Whispree.app' -maxdepth 1)" /Applications/`
4. 앱 재실행: `open /Applications/Whispree.app`
5. 커밋: feature/fix 단위로 커밋. 작업 도중에 중간 커밋하지 말 것 — 기능이 완결된 시점에만 커밋.

## Git 브랜치 전략

- **작업은 항상 `dev` 브랜치에서 수행.** 급한 hotfix를 제외하면 `main`에 직접 커밋하지 말 것.
- 커밋 후 별도 지시가 없으면 **`dev`에 커밋 + push까지만** 수행.
- **절대 `main`에 자의적으로 merge/push하지 말 것.** `main`은 배포 브랜치이므로 유저가 명시적으로 "배포해줘", "main에 merge해", "push해" 등 지시할 때만 `dev` → `main` merge 후 push. "커밋해"는 `dev` push만을 의미함.
- 커밋 전 현재 브랜치가 `dev`인지 확인. `main`이면 `dev`로 체크아웃 후 작업.

파일 추가/삭제 시 빌드 전 `xcodegen generate` 필수.

**코드 서명 주의**: 로컬 빌드는 Xcode Automatic Signing(개발자 인증서)을 사용. CI(release.yml)는 `CODE_SIGN_IDENTITY=""` + ad-hoc(`codesign --force --deep --sign -`)으로 서명. Sparkle 자동 업데이트는 ad-hoc ↔ ad-hoc만 호환되므로, 로컬 빌드한 앱에서는 자동 업데이트가 동작하지 않음 (개발자는 git pull + 빌드로 업데이트).

## Build & Test Commands

```bash
# Generate Xcode project (required after changing project.yml or adding/removing files)
xcodegen generate

# Build
xcodebuild -project Whispree.xcodeproj -scheme Whispree -destination 'platform=macOS,arch=arm64' build

# Run all tests (48 tests, includes E2E with real WhisperKit model loading ~24s first run)
xcodebuild -project Whispree.xcodeproj -scheme Whispree -destination 'platform=macOS,arch=arm64' test

# Deploy to /Applications
cp -R "$(find ~/Library/Developer/Xcode/DerivedData/Whispree-*/Build/Products/Debug -name 'Whispree.app' -maxdepth 1)" /Applications/
```

Metal Toolchain may be needed: `xcodebuild -downloadComponent MetalToolchain`

## What This Is

macOS menu bar STT app. Record speech → WhisperKit transcribe → LLM correct → paste into previous app. Runs locally on Apple Silicon (macOS 14+, arm64 only). XcodeGen (`project.yml`) generates the `.xcodeproj`.

## Architecture

**Recording pipeline** (orchestrated by `RecordingCoordinator`):
```
Hotkey(Ctrl+Shift+R) → AudioService (record + FFT) → STTProvider.transcribe() → LLMProvider.correct() → TextInsertionService.insertText()
```

**Quick Fix pipeline** (orchestrated by `AppDelegate` + `QuickFixService`):
```
Hotkey(Ctrl+Shift+D) → QuickFixService.captureSelectedText() (Cmd+C) → QuickFixPanelView → replaceText() (Cmd+V) + addToDictionary()
```

**Central state**: `AppState` (@MainActor ObservableObject) — holds transcription state, providers, settings, audio levels, history. All Views observe this.

**Provider abstraction**: Both STT and LLM use protocol-based providers switchable at runtime via `AppState.switchSTTProvider(to:)` / `switchLLMProvider(to:)`.

### STT Providers (`protocol STTProvider` — NOT @MainActor, runs off main thread)
- `WhisperKitProvider` — local CoreML+ANE, `whisper-large-v3-turbo`. Supports domain word → promptTokens injection
- `GroqSTTProvider` — Groq Cloud API, same model but server-side. Converts [Float] → WAV → multipart upload
- `MLXAudioProvider` — mlx-audio Python worker via stdin/stdout JSON pipe. Supports any mlx-audio STT model (default: Qwen3-ASR-1.7B-8bit)

### LLM Providers (`@MainActor protocol LLMProvider`)
- `NoneProvider` — passthrough, no correction
- `LocalLLMProvider` — Qwen3-4B via mlx-swift-lm, 5s timeout, word-edit-distance safety (0.5 threshold)
- `OpenAIProvider` — ChatGPT Responses API with SSE streaming. 인증 우선순위: (1) `CodexAuthService` (`~/.codex/auth.json`), (2) `OAuthService` (`~/.whispree/oauth.json`, PKCE 브라우저 로그인 fallback)

### Text Insertion
`TextInsertionService.insertText()` is async. Activates previous app → clipboard + CGEvent Cmd+V. Falls back to clipboard-only when no valid target app (e.g., recording from Settings window). Requires Accessibility permission (`AXIsProcessTrusted`).

## Key Design Decisions

- **STTProvider is NOT @MainActor** — ML inference must run off main thread to avoid MainActor deadlock. WhisperKit/Groq providers are `@unchecked Sendable`.
- **LLMProvider IS @MainActor** — LLM calls are lighter and need AppState access.
- **TextInsertionService uses `Task.sleep` not `Thread.sleep`** — yields MainActor during waits.
- **`RecordingCoordinator.startRecording()`** force-resets stuck states (transcribing/correcting/inserting) from previous failed pipelines.
- **`lastExternalApp`** tracked in `RecordingCoordinator` via `NSWorkspace.didActivateApplicationNotification` — captures the app before Whispree to avoid pasting into Whispree itself.
- **Word-edit-distance safety** in `LLMService`: word-based Levenshtein, threshold 0.5. Prevents LLM hallucination from replacing the entire text.
- **LLMService vs LLMProvider**: `LLMService`는 mlx-swift-lm 직접 사용 (모델 로딩/관리, `ModelManager`가 사용). `LLMProvider` 프로토콜은 교정 파이프라인 추상화 (`RecordingCoordinator`가 `AppState.llmProvider`를 통해 사용).
- **CorrectionPrompts** are in Korean with few-shot examples. 4가지 모드: `standard` (언어별 분기), `fillerRemoval` (필러 제거), `structured` (구조화), `custom` (사용자 정의). `codeSwitchPrompt` handles Korean-English codeswitching (밸리데이션 → validation).
- **QuickFix** (`Ctrl+Shift+D`): 선택 텍스트 캡처 → 교정 단어/매핑 입력 → 대상 앱에 교체 삽입 + 도메인 사전에 자동 등록. `QuickFixService` + `QuickFixPanelView`.

## Settings Persistence

`AppSettings` (Codable) saved to UserDefaults key `"WhispreeSettings"`. Key fields: `recordingMode`, `language`, `isLLMEnabled`, `hasCompletedOnboarding`, `launchAtLogin`, `showOverlay`, `correctionMode`, `customLLMPrompt`, `whisperModelId`, `llmModelId`, `mlxAudioModelId`, `sttProviderType`, `llmProviderType`, `openaiModel`, `groqApiKey`, `domainWordSets`.

## SPM Dependencies

- WhisperKit 0.9.0 — STT (CoreML + Neural Engine)
- mlx-swift-lm (main branch) — local LLM inference (MLXLLM, MLXLMCommon)
- KeyboardShortcuts 2.0.0+ — global hotkey
- LaunchAtLogin 1.0.0+ — login item
- Sparkle 2.6.0+ — 자동 업데이트 (appcast.xml via GitHub Pages)

## Audio & Visualization

`AudioService` captures at native sample rate, resamples to 16kHz mono for STT. Also computes 64-band FFT (Accelerate vDSP, voice-focused 80-3500Hz range) published as `frequencyBands` for the waveform view. `NeonWaveformView` renders slim rounded bars at 60fps with fast attack / slow decay smoothing.

## Concurrency Notes

- `AppState`, `RecordingCoordinator`, `AudioService`, `AppDelegate` — all `@MainActor`
- `WhisperKitProvider`, `GroqSTTProvider`, `MLXAudioProvider` — nonisolated (NOT @MainActor), `@unchecked Sendable`
- Audio tap callback runs on audio thread; dispatches to MainActor via `Task { @MainActor in ... }`
- `processPipeline()` runs in a `Task` on MainActor; `await sttProvider.transcribe()` suspends MainActor and runs inference on background executor

## Directory Documentation (AGENTS.md)

각 디렉토리별 상세 문서. 작업 영역에 따라 해당 파일을 참조:

- @AGENTS.md — 프로젝트 루트 (아키텍처 개요, 빌드, 설계 제약)
- @Whispree/AGENTS.md — 메인 앱 타겟 (파이프라인, 동시성 모델)
- @Whispree/App/AGENTS.md — 앱 진입점, AppState 중앙 상태
- @Whispree/Coordinators/AGENTS.md — RecordingCoordinator 파이프라인 오케스트레이션
- @Whispree/Models/AGENTS.md — 데이터 모델, 설정, 상태 enum
- @Whispree/Services/AGENTS.md — 서비스 레이어 개요
- @Whispree/Services/Audio/AGENTS.md — 마이크 녹음 + FFT
- @Whispree/Services/Auth/AGENTS.md — Codex 토큰 재사용 + OAuth PKCE 인증
- @Whispree/Services/Hotkey/AGENTS.md — 전역 단축키
- @Whispree/Services/LLM/AGENTS.md — LLM 교정 (None/Local/OpenAI)
- @Whispree/Services/ModelManagement/AGENTS.md — ML 모델 다운로드
- @Whispree/Services/QuickFix/AGENTS.md — Quick Fix (선택 텍스트 교정 + 사전 등록)
- @Whispree/Services/STT/AGENTS.md — STT 프로바이더 (WhisperKit/Groq/MLX Audio)
- @Whispree/Services/TextInsertion/AGENTS.md — 클립보드 + CGEvent 붙여넣기
- @Whispree/Views/AGENTS.md — SwiftUI UI 레이어
- @WhispreeTests/AGENTS.md — 유닛 + E2E 테스트
