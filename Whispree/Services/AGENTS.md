<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# Services

## Purpose
비즈니스 로직 서비스 레이어. 오디오 캡처, 인증, 핫키, LLM 교정, 모델 관리, Quick Fix, STT 추론, 텍스트 삽입.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Audio/` | 마이크 녹음 + FFT 시각화 (see `Audio/AGENTS.md`) |
| `Auth/` | Codex CLI 토큰 재사용 + OAuth PKCE 인증 (see `Auth/AGENTS.md`) |
| `Hotkey/` | 전역 단축키 (see `Hotkey/AGENTS.md`) |
| `LLM/` | LLM 텍스트 교정 — None/Local/OpenAI (see `LLM/AGENTS.md`) |
| `ModelManagement/` | ML 모델 다운로드/캐시 (see `ModelManagement/AGENTS.md`) |
| `QuickFix/` | 선택 텍스트 교정 + 도메인 사전 등록 (see `QuickFix/AGENTS.md`) |
| `STT/` | Speech-to-Text — WhisperKit/Groq/MLX Audio (see `STT/AGENTS.md`) |
| `TextInsertion/` | 클립보드 + CGEvent 붙여넣기 (see `TextInsertion/AGENTS.md`) |

## For AI Agents

### Working In This Directory
- **STTProvider는 NOT @MainActor**, **LLMProvider는 @MainActor** — 이 비대칭이 의도적 설계
- 새 서비스 추가 시: 프로토콜 정의 → 구현체 → AppState에 등록 → RecordingCoordinator에서 연결
- 모든 서비스는 `setup()` / `teardown()` 라이프사이클 따름

<!-- MANUAL: -->
