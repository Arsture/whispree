<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# STT

## Purpose
Speech-to-Text 프로바이더. 프로토콜 추상화로 WhisperKit / Groq Cloud 간 런타임 전환.

## Key Files

| File | Description |
|------|-------------|
| `STTProvider.swift` | `protocol STTProvider: AnyObject, Sendable` — **NOT @MainActor**, `transcribe()` + `transcribeStream()` |
| `STTService.swift` | STT 오케스트레이션, 프로바이더 호출 래핑 |
| `WhisperKitProvider.swift` | 로컬 CoreML+ANE, `whisper-large-v3-turbo`. 도메인 단어 → promptTokens 주입 지원. `@unchecked Sendable` |
| `GroqSTTProvider.swift` | Groq Cloud API — `[Float]` → WAV 변환 → multipart 업로드. `@unchecked Sendable` |

## For AI Agents

### Working In This Directory
- **STTProvider는 NOT @MainActor** — ML 추론은 반드시 백그라운드 실행 (MainActor deadlock 방지)
- 모든 프로바이더는 `@unchecked Sendable` — concurrent 접근 안전성은 내부적으로 보장
- `WhisperKitProvider`에 `promptTokens` 주입하면 도메인 특화 단어 인식률 향상
- `GroqSTTProvider`는 `[Float]` → WAV 바이너리 변환이 핵심 — 헤더 포맷 주의

### Testing
- `NotMyWhisperTests/Services/AudioServiceTests.swift` (오디오 관련)
- `NotMyWhisperTests/E2E/PipelineE2ETests.swift` (WhisperKit 실제 모델 로딩 포함, 첫 실행 ~24초)

<!-- MANUAL: -->
