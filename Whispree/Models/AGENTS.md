<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 | Updated: 2026-04-02 -->

# Models

## Purpose
데이터 모델과 설정 타입 정의. Codable 설정, 도메인 단어 세트, 모델 정보, 전사 상태 머신, 디바이스/모델 호환성 평가.

## Key Files

| File | Description |
|------|-------------|
| `AppSettings.swift` | `Codable` 설정 — STT/LLM 프로바이더 타입, API 키, 교정 모드, 언어, 도메인 단어 세트. UserDefaults `"WhispreeSettings"` 키로 저장 |
| `DomainWordSets.swift` | 도메인 특화 단어 세트 (프로그래밍, 의료 등) — STT promptTokens 주입 및 LLM glossary 용 |
| `ModelInfo.swift` | WhisperKit/LLM 모델 메타데이터 (이름, 크기, 상태) |
| `OpenAIModels.swift` | OpenAI API 응답 모델 (ChatCompletion, SSE 스트리밍 파싱) |
| `TranscriptionState.swift` | 상태 머신 enum — `idle → recording → transcribing → correcting → inserting → idle`, `ModelState` enum |
| `CapturedScreenshot.swift` | 녹음 중 캡처된 스크린샷 데이터 모델 — `Identifiable`, appName/timestamp/imageData |
| `DeviceCapability.swift` | Apple Silicon 하드웨어 감지 — chipName, totalRAMGB, memoryBandwidthGBs, gpuCores. `static let current` 싱글톤 |
| `LocalModelSpec.swift` | 지원 MLX 모델 레지스트리 — text(Qwen3 1.7B/4B/8B, Coder 30B, GLM-4.7) + vision(Qwen3 VL 4B). `ModelCapability` enum |
| `ModelCompatibility.swift` | 디바이스-모델 호환성 평가 (canirun.ai 방식) — `CompatibilityGrade` 6단계, RAM/속도 기반 점수 산출 |

## For AI Agents

### Working In This Directory
- `AppSettings` 변경 시 UserDefaults 직렬화 호환성 주의 (기존 사용자 설정 마이그레이션)
- `TranscriptionState`는 UI와 `RecordingCoordinator` 양쪽에서 참조 — 상태 추가 시 양쪽 핸들링 필요
- `DomainWordSets`는 STT Provider의 `promptTokens`와 LLM Provider의 `glossary`에 매핑
- `DeviceCapability` + `LocalModelSpec` + `ModelCompatibility`가 "Can I Run" 시스템 구성 — 모델 추가 시 세 파일 모두 확인
- `LocalModelSpec.supported` 배열에 모델 추가 시 `minMemoryGB`, `qualityScore` 설정 필수

### Testing
- `WhispreeTests/Models/AppSettingsTests.swift` — 설정 직렬화/역직렬화 + CorrectionMode 마이그레이션
- `WhispreeTests/Models/DomainWordSetsTests.swift` — 도메인 단어 세트
- `WhispreeTests/Services/LLMServiceTests.swift` — LocalModelSpec 검증

<!-- MANUAL: -->
