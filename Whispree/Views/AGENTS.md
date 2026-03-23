<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# Views

## Purpose
SwiftUI 뷰 레이어. 메뉴바, 대시보드, 설정, 온보딩, 전사 오버레이 UI.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Dashboard/` | 메인 대시보드 뷰 — `MainDashboardView.swift` |
| `MenuBar/` | 메뉴바 팝오버 — `MenuBarView.swift` |
| `Onboarding/` | 초기 설정 플로우 — `OnboardingView.swift` |
| `Settings/` | 설정 탭 뷰 — General, STT, LLM, Model, DomainWordSets |
| `Transcription/` | 전사 오버레이 + 히스토리 — `TranscriptionOverlayView.swift`, `TranscriptionHistoryView.swift` |

## Key Files (Settings/)

| File | Description |
|------|-------------|
| `SettingsView.swift` | 설정 탭 컨테이너 |
| `GeneralSettingsView.swift` | 일반 설정 (핫키, 시작 시 실행 등) |
| `LLMSettingsView.swift` | LLM 프로바이더 선택, API 키, 교정 모드 |
| `ModelSettingsView.swift` | 모델 다운로드/관리 |
| `DomainWordSetsView.swift` | 도메인 단어 세트 편집 |

## For AI Agents

### Working In This Directory
- 모든 뷰는 `AppState`를 `@EnvironmentObject`로 관찰
- `NeonWaveformView`(전사 오버레이)는 `frequencyBands` 기반 60fps 애니메이션 — 성능 민감
- Settings 뷰는 `AppSettings` 모델과 1:1 매핑 — 설정 필드 추가 시 뷰도 함께 수정
- 메뉴바 앱이므로 WindowGroup 대신 MenuBarExtra 패턴 사용

<!-- MANUAL: -->
