<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# Models

## Purpose
데이터 모델과 설정 타입 정의. Codable 설정, 도메인 단어 세트, 모델 정보, 전사 상태 머신.

## Key Files

| File | Description |
|------|-------------|
| `AppSettings.swift` | `Codable` 설정 — STT/LLM 프로바이더 타입, API 키, 교정 모드, 언어, 도메인 단어 세트. UserDefaults `"NotMyWhisperSettings"` 키로 저장 |
| `DomainWordSets.swift` | 도메인 특화 단어 세트 (프로그래밍, 의료 등) — STT promptTokens 주입 및 LLM glossary 용 |
| `ModelInfo.swift` | WhisperKit/LLM 모델 메타데이터 (이름, 크기, 상태) |
| `OpenAIModels.swift` | OpenAI API 응답 모델 (ChatCompletion, SSE 스트리밍 파싱) |
| `TranscriptionState.swift` | 상태 머신 enum — `idle → recording → transcribing → correcting → inserting → idle`, `ModelState` enum |

## For AI Agents

### Working In This Directory
- `AppSettings` 변경 시 UserDefaults 직렬화 호환성 주의 (기존 사용자 설정 마이그레이션)
- `TranscriptionState`는 UI와 `RecordingCoordinator` 양쪽에서 참조 — 상태 추가 시 양쪽 핸들링 필요
- `DomainWordSets`는 STT Provider의 `promptTokens`와 LLM Provider의 `glossary`에 매핑

### Testing
- `NotMyWhisperTests/Models/AppSettingsTests.swift` — 설정 직렬화/역직렬화
- `NotMyWhisperTests/Models/DomainWordSetsTests.swift` — 도메인 단어 세트

<!-- MANUAL: -->
