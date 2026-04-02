<!-- Generated: 2026-03-23 | Updated: 2026-04-02 -->

# Whispree

## Purpose
macOS STT 앱 (메뉴바 아이콘 + 메인 윈도우). 음성 녹음 → WhisperKit 전사 → LLM 교정 → 이전 앱에 자동 붙여넣기. 녹음 중 스크린샷 캡처 → VLM 컨텍스트 교정 지원. Quick Fix로 오인식 단어 즉시 교정 + 사전 등록. Apple Silicon(arm64) 전용, macOS 14+.

## Key Files

| File | Description |
|------|-------------|
| `project.yml` | XcodeGen 프로젝트 정의 — 타겟, SPM 패키지, 빌드 설정 |
| `CLAUDE.md` | AI 에이전트용 프로젝트 가이드 |
| `README.md` | 프로젝트 문서 |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Whispree/` | 메인 앱 타겟 — Swift/SwiftUI (see `Whispree/AGENTS.md`) |
| `WhispreeTests/` | 유닛 + E2E 테스트 (see `WhispreeTests/AGENTS.md`) |
| `mlx-worker/` | Python mlx-audio STT worker — stdin/stdout JSON 파이프 통신 |
| `docs/` | 추가 문서 |

## Architecture Overview

```
┌───────────────────────────────────────────────────┐
│  macOS Menu Bar App (SwiftUI)                     │
│                                                   │
│  Recording: Hotkey → AudioService → STT           │
│    → LLM correct → TextInsertionService           │
│  Screenshot: ContinuousScreenCaptureService       │
│    → VLM context → ScreenshotSelectionView        │
│  Quick Fix: Hotkey → capture selected text        │
│    → correction panel → replace + dictionary      │
│                                                   │
│  Orchestrator: RecordingCoordinator               │
│  Central State: AppState (@MainActor)             │
└───────────────────────────────────────────────────┘
         │                          │
    ┌────┴────┐              ┌──────┴──────┐
    │ STT     │              │ LLM         │
    │ Providers│              │ Providers   │
    ├─────────┤              ├─────────────┤
    │WhisperKit│(local)      │NoneProvider │
    │Groq API │(cloud)      │LocalText    │(MLX text)
    │MLX Audio│(local)      │LocalVision  │(MLX VLM)
    └─────────┘              │OpenAI      │(GPT SSE)
         │                   └─────────────┘
    ┌────┴────┐
    │mlx-worker│ (Python, stdin/stdout JSON)
    └─────────┘
```

## For AI Agents

### Build & Run
```bash
xcodegen generate                    # project.yml 변경 후
xcodebuild ... build                 # 빌드
xcodebuild ... test                  # 테스트 (E2E 포함)
```

### Key Design Constraints
- STTProvider는 **NOT @MainActor** (ML 추론 = 백그라운드)
- LLMProvider는 **@MainActor** (API 호출 + AppState 접근)
- word-edit-distance 안전장치 (threshold 0.5) — LLM 환각 방지
- Accessibility 권한 필수 (텍스트 삽입, CGEvent)
- Screen Recording 권한 필수 (스크린샷 캡처)

### SPM Dependencies
- WhisperKit 0.9.0 — STT (CoreML + Neural Engine)
- mlx-swift-lm — 로컬 LLM/VLM 추론 (MLXLLM, MLXVLM, MLXLMCommon)
- KeyboardShortcuts 2.0.0+ — 전역 핫키
- LaunchAtLogin 1.0.0+ — 로그인 항목
- Sparkle 2.6.0+ — 자동 업데이트

<!-- MANUAL: -->
