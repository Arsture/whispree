<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 | Updated: 2026-04-02 -->

# Whispree (App Target)

## Purpose
macOS 메뉴바 STT 앱의 메인 타겟. 녹음 → WhisperKit 전사 → LLM 교정 → 이전 앱에 붙여넣기. VLM 모델 사용 시 녹음 중 스크린샷을 캡처하여 컨텍스트 교정 지원.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `App/` | 앱 진입점, AppDelegate, 중앙 상태(AppState), 상수 (see `App/AGENTS.md`) |
| `Coordinators/` | 파이프라인 오케스트레이션 — RecordingCoordinator (see `Coordinators/AGENTS.md`) |
| `Models/` | 데이터 모델, 설정, 상태 enum, 디바이스/모델 호환성 (see `Models/AGENTS.md`) |
| `Services/` | 비즈니스 로직 서비스 9개 (see `Services/AGENTS.md`) |
| `Views/` | SwiftUI UI 레이어 (see `Views/AGENTS.md`) |
| `Resources/` | Assets.xcassets, Info.plist, Entitlements |

## Architecture (Pipeline Flow)

```
Recording: Hotkey → AudioService (record + FFT)
  → [ContinuousScreenCaptureService (VLM 활성 시)]
  → STTProvider.transcribe()
  → LLMProvider.correct(screenshots:)
  → [ScreenshotSelectionView (스크린샷 선택)]
  → TextInsertionService.insertText()

Quick Fix: Hotkey → QuickFixService.captureSelectedText()
  → QuickFixPanelView → replaceText() + addToDictionary()
```

`RecordingCoordinator`가 녹음 파이프라인을 오케스트레이션. Quick Fix는 `AppDelegate`가 직접 조율.

## For AI Agents

### Working In This Directory
- `project.yml` (XcodeGen) → 파일 추가/삭제 후 반드시 `xcodegen generate`
- macOS 14+, arm64 전용 (Apple Silicon)
- Swift 5.9, SwiftUI lifecycle
- 주요 SPM 의존성: WhisperKit 0.9.0, mlx-swift-lm (MLXLLM + MLXVLM), KeyboardShortcuts, LaunchAtLogin, Sparkle

### Concurrency Model
- `@MainActor`: AppState, RecordingCoordinator, AudioService, AppDelegate, LLMProvider, ContinuousScreenCaptureService
- **NOT @MainActor**: STTProvider (WhisperKit/Groq/MLX Audio), ScreenCaptureService, EventTapHotkeyService — ML 추론과 이벤트 탭은 백그라운드
- 오디오 탭: 오디오 스레드 → `Task { @MainActor in }` 디스패치

<!-- MANUAL: -->
