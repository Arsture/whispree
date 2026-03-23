<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# Coordinators

## Purpose
파이프라인 오케스트레이션. 녹음 → STT → LLM 교정 → 텍스트 삽입 전체 흐름을 조율.

## Key Files

| File | Description |
|------|-------------|
| `RecordingCoordinator.swift` | `@MainActor` — 녹음 시작/중지, `processPipeline()` (STT→LLM→Insert), 이전 앱 추적(`lastExternalApp`) |

## For AI Agents

### Working In This Directory
- `RecordingCoordinator`는 파이프라인의 핵심. `startRecording()` → `stopRecording()` → `processPipeline()` 순서
- `processPipeline()`은 `Task`로 MainActor에서 실행, `await sttProvider.transcribe()`로 백그라운드 추론 후 복귀
- `startRecording()`은 stuck 상태(transcribing/correcting/inserting)를 강제 리셋
- `lastExternalApp`은 `NSWorkspace.didActivateApplicationNotification`으로 추적 — 텍스트를 삽입할 대상 앱

### Dependencies
- `AppState` (상태 읽기/쓰기)
- `AudioService` (녹음)
- `TextInsertionService` (결과 붙여넣기)
- STT/LLM Provider (AppState를 통해 간접 참조)

<!-- MANUAL: -->
