<!-- Generated: 2026-03-23 | Updated: 2026-06-09 -->

# Whispree

## Purpose
macOS STT 앱 (메뉴바 아이콘 + 메인 윈도우). 음성 녹음 → dictation job queue → provider-bounded STT/LLM 병렬 후처리 → FIFO delivery로 이전 앱에 자동 붙여넣기. 녹음 중 스크린샷 캡처 → VLM 컨텍스트 교정 지원. Quick Fix로 오인식 단어 즉시 교정 + 사전 등록. Apple Silicon(arm64) 전용, macOS 14+.

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
│  Recording: Hotkey → AudioService → DictationQueue│
│    → provider-bounded STT/LLM parallel processing │
│    → FIFO delivery → TextInsertionService         │
│  Screenshot: ContinuousScreenCaptureService       │
│    → VLM context → FIFO ScreenshotSelectionView   │
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


### Public Docs Site

- `docs-site/` is the nested Vercel-hosted public documentation site for Whispree. It uses Astro Starlight and should stay static-first.
- Before merging/deploying to `main`, update affected docs under `docs-site/src/content/docs/` and the relevant feature SSoT, or record a clear `No docs needed:` rationale for internal-only changes.
- Keep root `DESIGN.md` as the macOS app design contract; use `docs-site/DESIGN.md` for docs website UX/UI decisions.
- Vercel deploys must use Root Directory `docs-site` (or `vercel docs-site` from the repository root). Do not deploy the repository root as the docs project.

### Key Design Constraints
- STTProvider는 **NOT @MainActor** (ML 추론 = 백그라운드)
- LLMProvider는 **@MainActor** (API 호출 + AppState 접근)
- word-edit-distance 안전장치 (threshold 0.5) — LLM 환각 방지
- Queue admission은 작은 고정 cap 없음; STT/LLM provider별 concurrency 제한과 FIFO delivery 직렬화는 `DictationQueueState`/`RecordingCoordinator`가 담당
- ESC는 scoped/nested cancel만 허용: preview/recording/active delivery/foreground item. 전체 queue/background job 일괄 취소 금지
- Accessibility 권한 필수 (텍스트 삽입, CGEvent)
- Screen Recording 권한 필수 (스크린샷 캡처)

### SPM Dependencies
- WhisperKit 0.9.0+ — STT (CoreML + Neural Engine); resolved package may be newer
- mlx-swift-lm — 로컬 LLM/VLM 추론 (MLXLLM, MLXVLM, MLXLMCommon)
- KeyboardShortcuts 2.0.0+ — 전역 핫키
- LaunchAtLogin 1.0.0+ — 로그인 항목
- Sparkle 2.6.0+ — 자동 업데이트

<!-- MANUAL: -->
