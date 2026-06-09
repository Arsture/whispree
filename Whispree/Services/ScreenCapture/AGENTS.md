<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-04-02 | Updated: 2026-06-09 -->

# ScreenCapture

## Purpose
녹음 중 스크린샷 캡처. 단일 윈도우 캡처 유틸리티 + 앱 전환/스크롤/클릭 감지 기반 디바운스 연속 캡처.

## Key Files

| File | Description |
|------|-------------|
| `ScreenCaptureService.swift` | 저수준 스크린샷 유틸리티 — CGWindowListCopyWindowInfo로 frontmost 앱 윈도우 캡처, JPEG 0.7 압축. Screen Recording 권한 필요. **NOT @MainActor** |
| `ContinuousScreenCaptureService.swift` | `@MainActor` — 녹음 중 지능형 디바운스 캡처. 앱 포커스 전환/스크롤/클릭 이벤트 모니터링, 1.5초 idle 후 캡처, 최대 20장 |

## For AI Agents

### Working In This Directory
- **Screen Recording 권한 필수** — `CGPreflightScreenCaptureAccess()` / `CGRequestScreenCaptureAccess()`
- `ScreenCaptureService`는 NOT @MainActor — 저수준 CoreGraphics 호출
- `ContinuousScreenCaptureService`는 @MainActor — NSWorkspace/NSEvent 글로벌 모니터 사용
- 디바운스 로직: 앱 전환 시 이전 앱 flush + 새 앱 1.5초 대기, 스크롤/클릭 시 타이머 리셋
- `maxCaptures=20`으로 메모리 보호
- `RecordingCoordinator`가 VLM 활성 시에만 recording 동안 `startMonitoring()`/`stopMonitoring()` 호출. Audio start 실패/cancel 시 `reset()`으로 모니터와 캡처를 정리해야 한다.
- 캡처 결과는 recording 중 `AppState.capturedScreenshots`에 표시되고, stop 시 dictation job snapshots로 저장된다. `ScreenshotSelectionView`는 FIFO delivery head job의 screenshots만 표시한다.

<!-- MANUAL: -->
