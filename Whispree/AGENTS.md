<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# Whispree (App Target)

## Purpose
macOS 메뉴바 STT 앱의 메인 타겟. 녹음 → WhisperKit 전사 → LLM 교정 → 이전 앱에 붙여넣기.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `App/` | 앱 진입점, AppDelegate, 중앙 상태(AppState), 상수 (see `App/AGENTS.md`) |
| `Coordinators/` | 파이프라인 오케스트레이션 — RecordingCoordinator (see `Coordinators/AGENTS.md`) |
| `Models/` | 데이터 모델, 설정, 상태 enum (see `Models/AGENTS.md`) |
| `Services/` | 비즈니스 로직 서비스 7개 (see `Services/AGENTS.md`) |
| `Views/` | SwiftUI UI 레이어 (see `Views/AGENTS.md`) |
| `Resources/` | Assets.xcassets, Info.plist, Entitlements |

## Architecture (Pipeline Flow)

```
Hotkey → AudioService (record + FFT)
       → STTProvider.transcribe()
       → LLMProvider.correct()
       → TextInsertionService.insertText()
```

`RecordingCoordinator`가 이 파이프라인 전체를 오케스트레이션.

## For AI Agents

### Working In This Directory
- `project.yml` (XcodeGen) → 파일 추가/삭제 후 반드시 `xcodegen generate`
- macOS 14+, arm64 전용 (Apple Silicon)
- Swift 5.9, SwiftUI lifecycle
- 주요 SPM 의존성: WhisperKit 0.9.0, mlx-swift-lm (main), KeyboardShortcuts, LaunchAtLogin

### Concurrency Model
- `@MainActor`: AppState, RecordingCoordinator, AudioService, AppDelegate, LLMProvider
- **NOT @MainActor**: STTProvider (WhisperKit/Groq/Lightning) — ML 추론은 백그라운드
- 오디오 탭: 오디오 스레드 → `Task { @MainActor in }` 디스패치

<!-- MANUAL: -->
