<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 | Updated: 2026-04-02 -->

# Views

## Purpose
SwiftUI 뷰 레이어. 대시보드, 설정, 온보딩, 전사 오버레이, Quick Fix UI, 스크린샷 선택.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Dashboard/` | 메인 대시보드 뷰 — `MainDashboardView.swift` |
| `Design/` | 디자인 토큰 + 공통 UI 컴포넌트 — DesignTokens, SettingsCard, StatusBadge, CompatibilityBadge, ModelMetricsView |
| `MenuBar/` | 메뉴바 팝오버 — `MenuBarView.swift` |
| `Onboarding/` | 초기 설정 플로우 — `OnboardingView.swift` |
| `QuickFix/` | Quick Fix 패널 — `QuickFixPanelView.swift` (단어/매핑 교정 입력) |
| `Settings/` | 설정 탭 뷰 — General, STT, LLM, Model, DomainWordSets, ShortcutRecorder |
| `Transcription/` | 전사 오버레이 + 히스토리 — `TranscriptionOverlayView.swift`, `TranscriptionHistoryView.swift` |

## Key Files

| File | Description |
|------|-------------|
| `UnifiedView.swift` | 메인 윈도우 — 사이드바 네비게이션(Home/Settings/History) + 디테일 뷰 |
| `ScreenshotSelectionView.swift` | 스크린샷 선택 모달 — 키보드 네비게이션(↑↓/Space/Enter/Esc), 썸네일 + 타임스탬프 |

## Key Files (Design/)

| File | Description |
|------|-------------|
| `DesignTokens.swift` | 색상, 폰트, 간격 등 디자인 토큰 |
| `SettingsCard.swift` | 설정 카드 컨테이너 |
| `SettingsRow.swift` | 설정 행 컴포넌트 |
| `StatusBadge.swift` | 상태 표시 뱃지 |
| `CompatibilityBadge.swift` | 모델 호환성 등급 캡슐 뱃지 — CompatibilityGrade별 색상 매핑 |
| `ModelMetricsView.swift` | 모델 메트릭 표시 — 크기, RAM%, tok/s, 레이턴시, 품질 점수 |

## Key Files (Settings/)

| File | Description |
|------|-------------|
| `SettingsView.swift` | 설정 탭 컨테이너 |
| `GeneralSettingsView.swift` | 일반 설정 (핫키, 시작 시 실행 등) |
| `STTSettingsView.swift` | STT 프로바이더 선택 + 모델 메트릭 표시 |
| `LLMSettingsView.swift` | LLM 프로바이더 선택, 모델 선택(text/vision), 스크린샷 컨텍스트 토글, 교정 모드, OpenAI 인증 |
| `ModelSettingsView.swift` | 모델 다운로드/관리 + 디바이스 정보 + Can I Run 호환성 |
| `DomainWordSetsView.swift` | 도메인 단어 세트 편집 |
| `ShortcutRecorderButton.swift` | 단축키 녹화 버튼 — EventTapHotkeyService 연동, 충돌 감지 팝오버 |

## For AI Agents

### Working In This Directory
- 모든 뷰는 `AppState`를 `@EnvironmentObject`로 관찰
- `NeonWaveformView`(전사 오버레이)는 `frequencyBands` 기반 60fps 애니메이션 — 성능 민감
- Settings 뷰는 `AppSettings` 모델과 1:1 매핑 — 설정 필드 추가 시 뷰도 함께 수정
- `ScreenshotSelectionView`는 `AppState.screenshotSelectionCallback` 통해 결과 전달
- `ModelMetricsView`와 `CompatibilityBadge`는 STT/LLM/Model 설정 뷰에서 재사용
- NSStatusItem(메뉴바 아이콘) + NSWindow(메인 윈도우) 패턴 사용. MenuBarExtra 미사용

<!-- MANUAL: -->
