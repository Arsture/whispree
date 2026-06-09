<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-23 | Updated: 2026-06-09 -->

# Hotkey

## Purpose
전역 단축키 관리. KeyboardShortcuts 라이브러리 + CGEventTap 기반 저수준 핫키 등록, 시스템 단축키 충돌 감지, 병렬 dictation queue의 scoped ESC cancellation UX를 담당.

## Key Files

| File | Description |
|------|-------------|
| `HotkeyManager.swift` | 전역 핫키 등록/해제, KeyboardShortcuts 패키지 래핑, `reloadHotkeys()` |
| `EventTapHotkeyService.swift` | CGEventTap(cghidEventTap) 기반 전역 핫키 — macOS 시스템 단축키보다 먼저 인터셉트. 단축키 녹화 모드, scoped ESC 핸들러(preview→selection/delivery→recording/foreground item) |
| `ShortcutConflictDetector.swift` | 53+ 알려진 macOS 시스템 단축키와의 충돌 감지 — Spotlight, Mission Control, 앱 전환기 등 |

## For AI Agents

### Working In This Directory
- `KeyboardShortcuts` SPM 패키지 의존성
- `EventTapHotkeyService`는 **NOT @MainActor** — CGEventTap은 저수준 이벤트 처리, Accessibility 권한 필수
- `EventTapHotkeyService.shared` 싱글톤 — `start()`로 이벤트 탭 설치, `stop()`으로 제거
- 단축키 녹화: `startRecording(onCapture:onCancel:onModifiers:)` → 수정자 키 1개 이상 필요, Esc로 취소
- 통합 ESC 핸들러: preview → screenshot selection/active delivery → active recording → 명시 foreground queue item 순서. passive background STT/LLM 또는 전체 queue를 전역 ESC로 취소하지 말 것.
- `ShortcutConflictDetector.checkConflict(for:)`로 충돌 확인 후 UI에서 경고 팝오버 표시
- 핫키 변경 시 `AppDelegate`와 `SettingsView`(ShortcutRecorderButton) 연동 확인
- Toggle mode는 `appState.isRecording` 기준으로 start/stop한다. `transcriptionState == .idle` 요구를 되살리면 “후처리 중 새 녹음” UX가 깨진다.
- `eventTap.isPipelineActive`는 ESC를 소비해도 되는 명시 scope가 있을 때만 true여야 한다. 상태 표시가 `.transcribing/.correcting`이라는 이유만으로 ESC를 삼키지 말 것; overlay에 `Cancel #N esc`처럼 foreground item cancel affordance가 있어야 한다.

<!-- MANUAL: -->
