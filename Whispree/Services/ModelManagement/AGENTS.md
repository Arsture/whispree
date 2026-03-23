<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# ModelManagement

## Purpose
ML 모델 다운로드 및 라이프사이클 관리. WhisperKit/LLM 모델 다운로드 진행률 추적.

## Key Files

| File | Description |
|------|-------------|
| `ModelManager.swift` | 모델 다운로드, 진행률 트래킹, 캐시 관리 |

## For AI Agents

### Working In This Directory
- 모델 다운로드는 비동기 — 진행률이 `AppState.whisperDownloadProgress` / `llmDownloadProgress`에 반영
- 네트워크 실패 시 재시도 로직 확인

<!-- MANUAL: -->
