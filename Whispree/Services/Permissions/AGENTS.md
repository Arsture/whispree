# Permissions

## Purpose
앱 전역 권한 상태 중앙 관리. Microphone / Accessibility / ScreenRecording / Automation(per-bundleID)을 단일 `@MainActor ObservableObject` 싱글톤으로 통합.

## Key Files

| File | Description |
|------|-------------|
| `PermissionManager.swift` | `@MainActor final class PermissionManager: ObservableObject` 싱글톤. 권한 조회/요청/설정 딥링크 API 제공. 5초 폴링으로 자동 갱신 |

## API Summary

```swift
PermissionManager.shared

// Published 상태
@Published private(set) var microphone: Status
@Published private(set) var accessibility: Status
@Published private(set) var screenRecording: Status
@Published private(set) var automation: [String: Status]   // bundleID → Status

// 조회 (non-prompting)
func refreshAll()
func refresh(_ kind: PermissionKind)

// 요청 (OS 프롬프트 발생 가능)
func requestMicrophone() async -> Status
func requestAccessibility()           // 비동기 프롬프트, 즉시 반환
func requestScreenRecording() async -> Status
func requestAutomation(bundleID: String) async -> Status

// 시스템 설정 딥링크
func openSystemSettings(for kind: PermissionKind)
```

## For AI Agents

### AEDeterminePermissionToAutomateTarget 주의사항

- **반드시 background queue** (`DispatchQueue.global`)에서 호출 — 사용자 응답을 블로킹 대기함. MainActor에서 직접 호출하면 UI 프리즈 발생.
- `askIfNeeded: true`(요청)와 `askIfNeeded: false`(조회 전용) 두 모드 존재.
- **Music hang bug**: `com.apple.Music` 대상 요청 전 반드시 `NSRunningApplication.activate()` 호출. 미실행 시 `AEDeterminePermissionToAutomateTarget`이 무한 대기할 수 있음.
- `procNotFound (-600)`: 대상 앱이 미실행 상태 → `.notDetermined` 반환 (오류 아님).
- `errAEEventNotPermitted (-1743)`: 사용자가 명시적으로 거부한 상태 → `.denied`.

### Known Automation Targets
`PermissionManager.knownAutomationTargets`: Music, Spotify, Chrome, iTerm2, SystemEvents.

새 Automation 대상 추가 시 이 배열에 bundleID 추가.

### Status Enum
`.notDetermined` / `.granted` / `.denied` — 세 가지 상태만 사용. iOS의 `AVAuthorizationStatus`처럼 세분화하지 않음.
