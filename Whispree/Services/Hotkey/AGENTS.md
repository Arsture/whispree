<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 | Updated: 2026-04-02 -->

# Hotkey

## Purpose
전역 단축키 관리. KeyboardShortcuts 라이브러리 + CGEventTap 기반 저수준 핫키 등록. 시스템 단축키 충돌 감지.

## Key Files

| File | Description |
|------|-------------|
| `HotkeyManager.swift` | 전역 핫키 등록/해제, KeyboardShortcuts 패키지 래핑, `reloadHotkeys()` |
| `EventTapHotkeyService.swift` | CGEventTap(cghidEventTap) 기반 전역 핫키 — macOS 시스템 단축키보다 먼저 인터셉트. 단축키 녹화 모드, 통합 ESC 핸들러(preview→selection→pipeline) |
| `ShortcutConflictDetector.swift` | 53+ 알려진 macOS 시스템 단축키와의 충돌 감지 — Spotlight, Mission Control, 앱 전환기 등 |

## For AI Agents

### Working In This Directory
- `KeyboardShortcuts` SPM 패키지 의존성
- `EventTapHotkeyService`는 **NOT @MainActor** — CGEventTap은 저수준 이벤트 처리, Accessibility 권한 필수
- `EventTapHotkeyService.shared` 싱글톤 — `start()`로 이벤트 탭 설치, `stop()`으로 제거
- 단축키 녹화: `startRecording(onCapture:onCancel:onModifiers:)` → 수정자 키 1개 이상 필요, Esc로 취소
- 통합 ESC 핸들러: `isPreviewOpen` → `isSelectionActive` → `isPipelineActive` 우선순위로 처리
- `ShortcutConflictDetector.checkConflict(for:)`로 충돌 확인 후 UI에서 경고 팝오버 표시
- 핫키 변경 시 `AppDelegate`와 `SettingsView`(ShortcutRecorderButton) 연동 확인

<!-- MANUAL: -->
