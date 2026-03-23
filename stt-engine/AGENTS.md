<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# stt-engine

## Purpose
Python FastAPI 기반 STT 서버. Lightning-SimulWhisper + MLX 백엔드. `LightningWhisperProvider`가 이 서버와 HTTP 통신.

## Key Files

| File | Description |
|------|-------------|
| `server.py` | FastAPI 앱 — `/transcribe` (base64 오디오 → 텍스트), `/health`, lifespan 모델 로딩 |
| `pyproject.toml` | Python 프로젝트 설정, 의존성 (fastapi, uvicorn, numpy, lightning-whisper-mlx) |
| `uv.lock` | uv 패키지 매니저 lock 파일 |
| `src/` | WhisperEngine 구현 (`src/whisper_engine.py`) |
| `mlx_models/` | 다운로드된 MLX 모델 캐시 |

## For AI Agents

### Working In This Directory
- Python 환경: `.venv/` (uv로 관리)
- 서버 시작: `cd stt-engine && uv run python server.py`
- CoreML + MLX 백엔드 — Apple Silicon 전용
- Swift 앱(`LightningWhisperProvider`)은 `localhost:8000`으로 통신
- `stub mode`: lightning-whisper-mlx 미설치 시 경고만 출력하고 빈 서버로 실행

### API Endpoints
- `POST /transcribe` — `{ audio_base64, language?, prompt? }` → `{ text, segments, language }`
- `GET /health` — `{ status, model, backend }`

<!-- MANUAL: -->
