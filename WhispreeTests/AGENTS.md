<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 | Updated: 2026-04-02 -->

# WhispreeTests

## Purpose
유닛 테스트 + E2E 테스트. E2E는 실제 WhisperKit 모델 로딩 포함 (첫 실행 ~24초).

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Coordinators/` | RecordingCoordinator 테스트 (현재 비어있음) |
| `E2E/` | 전체 파이프라인 E2E 테스트 |
| `Models/` | AppSettings, DomainWordSets 직렬화 테스트 |
| `Services/` | LLM 교정, word-edit-distance, 모델 스펙 테스트 |

## Key Files

| File | Description |
|------|-------------|
| `E2E/PipelineE2ETests.swift` | WhisperKit 모델 로딩 + 전사 + LLM 교정 + 프로바이더 전환 E2E |
| `Models/AppSettingsTests.swift` | 설정 Codable 직렬화/역직렬화 + CorrectionMode 마이그레이션 |
| `Models/DomainWordSetsTests.swift` | 도메인 단어 세트 로직 + 프롬프트 텍스트 빌딩 |
| `Services/AudioServiceTests.swift` | 오디오 캡처/리샘플링 (placeholder) |
| `Services/LLMServiceTests.swift` | LocalTextProvider word-edit-distance + LocalModelSpec 검증 + 프로바이더 속성 테스트 |

## For AI Agents

### Running Tests
```bash
xcodebuild -project Whispree.xcodeproj -scheme Whispree -destination 'platform=macOS,arch=arm64' test
```

### Working In This Directory
- E2E 테스트는 실제 모델을 다운로드/로딩 — CI에서 첫 실행 시 시간 소요
- `LLMServiceTests`는 `LocalTextProvider.wordEditDistance()` 직접 테스트 (LLMService 삭제됨)
- `Coordinators/` 디렉토리는 현재 비어있음 — RecordingCoordinator 테스트 추가 가능 영역
- 테스트 타겟은 `TEST_HOST`로 메인 앱에 주입됨 (unit test bundle)

<!-- MANUAL: -->
