<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 | Updated: 2026-06-09 -->

# Whispree (App Target)

## Purpose
macOS 메뉴바 STT 앱의 메인 타겟. 녹음은 즉시 job queue에 들어가고, STT/LLM 후처리는 provider별 concurrency 정책에 따라 병렬 처리되며, 최종 스크린샷 선택/텍스트·이미지 삽입은 FIFO로 직렬 delivery된다. VLM 모델 사용 시 녹음 중 스크린샷을 캡처하여 컨텍스트 교정 지원.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `App/` | 앱 진입점, AppDelegate, 중앙 상태(AppState), 상수 (see `App/AGENTS.md`) |
| `Coordinators/` | 병렬 dictation job queue + FIFO delivery 오케스트레이션 — RecordingCoordinator (see `Coordinators/AGENTS.md`) |
| `Models/` | 데이터 모델, 설정, 상태 enum, 디바이스/모델 호환성 (see `Models/AGENTS.md`) |
| `Services/` | 비즈니스 로직 서비스 레이어 (see `Services/AGENTS.md`) |
| `Views/` | SwiftUI UI 레이어 (see `Views/AGENTS.md`) |
| `Resources/` | Assets.xcassets, Info.plist, Entitlements |

## Architecture (Queue + Delivery Flow)

```
Recording: Hotkey → AudioService (record + FFT)
  → [ContinuousScreenCaptureService (VLM 활성 시)]
  → DictationQueueState.enqueue(job snapshot + audio + target context + screenshots)

Processing (provider-bounded parallel):
  queued job → STTProvider.transcribe()
    → [LLMProvider.correct(screenshots:)]
    → readyForDelivery

Delivery (strict FIFO, serialized, blocked while recording):
  ready head job → [ScreenshotSelectionView]
    → TextInsertionService.insertText()/insertImages()
    → terminal cleanup/history

Quick Fix: Hotkey → QuickFixService.captureSelectedText()
  → QuickFixPanelView → replaceText() + addToDictionary()
```

`RecordingCoordinator`가 active recording, background processing tasks, single FIFO delivery task를 오케스트레이션. Quick Fix는 `AppDelegate`가 직접 조율.

## For AI Agents

### Working In This Directory
- `project.yml` (XcodeGen) → 파일 추가/삭제 후 반드시 `xcodegen generate`
- macOS 14+, arm64 전용 (Apple Silicon)
- Swift 5.9, SwiftUI lifecycle
- 주요 SPM 의존성: WhisperKit 0.9.0+ (resolved package may be newer), mlx-swift-lm (MLXLLM + MLXVLM), KeyboardShortcuts, LaunchAtLogin, Sparkle

### Concurrency Model
- `@MainActor`: AppState, RecordingCoordinator, DictationQueueState, AudioService, AppDelegate, LLMProvider, ContinuousScreenCaptureService
- **NOT @MainActor**: STTProvider (WhisperKit/Groq/MLX Audio), ScreenCaptureService, EventTapHotkeyService — ML 추론과 이벤트 탭은 백그라운드
- Queue admission은 작은 고정 cap 없음. 단, provider별 STT/LLM permit 정책은 `DictationProviderConcurrencyPolicy`가 관리.
- STT/LLM processing은 병렬 가능하지만 delivery/text/image insertion은 FIFO 직렬이며 녹음 중에는 block.
- ESC는 nested scope만 취소: preview → active recording → active delivery/screenshot selection → 명시 foreground job. 전체 queue/background job 일괄 취소 금지.
- 오디오 탭: 오디오 스레드 → `Task { @MainActor in }` 디스패치

<!-- MANUAL: -->
