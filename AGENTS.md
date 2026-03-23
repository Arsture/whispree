<!-- Generated: 2026-03-23 -->

# NotMyWhisper

## Purpose
macOS 메뉴바 STT 앱. 음성 녹음 → WhisperKit 전사 → LLM 교정 → 이전 앱에 자동 붙여넣기. Apple Silicon(arm64) 전용, macOS 14+, 로컬 온디바이스 실행.

## Key Files

| File | Description |
|------|-------------|
| `project.yml` | XcodeGen 프로젝트 정의 — 타겟, SPM 패키지, 빌드 설정 |
| `CLAUDE.md` | AI 에이전트용 프로젝트 가이드 |
| `README.md` | 프로젝트 문서 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `NotMyWhisper/` | 메인 앱 타겟 — Swift/SwiftUI (see `NotMyWhisper/AGENTS.md`) |
| `NotMyWhisperTests/` | 유닛 + E2E 테스트 48개 (see `NotMyWhisperTests/AGENTS.md`) |
| `mlx-worker/` | Python mlx-audio STT worker — stdin/stdout JSON 파이프 통신 |
| `docs/` | 추가 문서 |

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│  macOS Menu Bar App (SwiftUI)               │
│                                             │
│  Hotkey → AudioService (record + FFT)       │
│         → STTProvider.transcribe()          │
│         → LLMProvider.correct()             │
│         → TextInsertionService.insertText() │
│                                             │
│  Orchestrator: RecordingCoordinator         │
│  Central State: AppState (@MainActor)       │
└─────────────────────────────────────────────┘
         │                          │
    ┌────┴────┐              ┌──────┴──────┐
    │ STT     │              │ LLM         │
    │ Providers│              │ Providers   │
    ├─────────┤              ├─────────────┤
    │WhisperKit│(local)      │NoneProvider │
    │Groq API │(cloud)      │LocalLLM     │(Qwen3-4B)
    │MLX Audio│(local)      │OpenAI       │(GPT SSE)
    └─────────┘              └─────────────┘
         │
    ┌────┴────┐
    │mlx-worker│ (Python, stdin/stdout JSON)
    └─────────┘
```

## For AI Agents

### Build & Run
```bash
xcodegen generate                    # project.yml 변경 후
xcodebuild ... build                 # 빌드
xcodebuild ... test                  # 테스트 (48개, E2E 포함)
```

### Key Design Constraints
- STTProvider는 **NOT @MainActor** (ML 추론 = 백그라운드)
- LLMProvider는 **@MainActor** (가벼운 API 호출 + AppState 접근)
- word-edit-distance 안전장치 (threshold 0.5) — LLM 환각 방지
- Accessibility 권한 필수 (텍스트 삽입)

### SPM Dependencies
- WhisperKit 0.9.0, mlx-swift-lm (main), KeyboardShortcuts 2.0.0+, LaunchAtLogin 1.0.0+

<!-- MANUAL: -->
