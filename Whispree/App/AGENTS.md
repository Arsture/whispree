<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 -->

# App

## Purpose
앱 진입점과 전역 상태 관리. SwiftUI App lifecycle, AppDelegate, 중앙 상태(`AppState`), 상수 정의.

## Key Files

| File | Description |
|------|-------------|
| `WhispreeApp.swift` | SwiftUI `@main` 진입점, Scene 구성 |
| `AppDelegate.swift` | NSApplicationDelegate — 메뉴바 아이콘, 핫키, 윈도우 관리 |
| `AppState.swift` | `@MainActor ObservableObject` 중앙 상태 — 전사 상태, 프로바이더, 오디오 레벨, 설정, 히스토리 |
| `Constants.swift` | 앱 전역 상수 (모델명, URL, 기본값 등) |

## For AI Agents

### Working In This Directory
- `AppState`는 **모든 View와 Service가 참조**하는 중앙 상태. 프로퍼티 변경 시 영향 범위를 반드시 확인
- `AppState`는 `@MainActor` — UI 스레드에서만 접근
- Provider 전환 로직(`switchSTTProvider`, `switchLLMProvider`)이 여기에 있음
- `AppDelegate`는 lifecycle 관리 — NSStatusItem(메뉴바 아이콘) + NSWindow(메인 윈도우). Dock 아이콘 표시(`LSUIElement=false`)는 의도적 설계 (윈도우 기반 UI)

### Testing
- `AppState` 변경 시 `WhispreeTests/Models/` 테스트 확인
- Provider 전환 로직은 E2E 테스트(`PipelineE2ETests`)에서 검증

<!-- MANUAL: -->
