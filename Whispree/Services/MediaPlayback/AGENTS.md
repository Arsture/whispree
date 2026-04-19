# MediaPlayback

## Purpose
macOS 시스템 전역 미디어 재생 제어. 녹음 시작 시 재생 중인 음악/영상을 일시정지하고 녹음 종료 시 재개.

## Key Files

| File | Description |
|------|-------------|
| `MediaPlaybackService.swift` | `@MainActor` — 상태 체크(MediaRemote isPlaying + Music/Spotify AppleScript fallback) + 미디어 키 이벤트로 pause/resume |

## For AI Agents

### Working In This Directory

#### 왜 미디어 키 이벤트인가
macOS 26(Tahoe)부터 `MRMediaRemoteSendCommand`가 non-Apple 프로세스에 대해 no-op 처리되어 실제 pause/resume이 먹히지 않음. **`NSEvent.systemDefined` subtype 8 + NX_KEYTYPE_PLAY(16)** 다운/업 페어를 `.cghidEventTap`으로 post하는 방식이 Apple Music, Spotify, YouTube(Safari/Chrome) 등 macOS Now Playing 세션을 등록한 모든 소스에 시스템 차원에서 라우팅됨 (MediaKeyTap 등 오픈소스의 표준 패턴).

#### 상태 체크 (isPlaying)
미디어 키는 **토글**이므로 "재생 중인가"를 반드시 사전 확인해야 함 (정지 상태에서 녹음 시작 시 오히려 재생되는 케이스 방지). 순서:
1. `MRMediaRemoteGetNowPlayingApplicationIsPlaying` (private, 500ms timeout — 읽기 API는 macOS 26에서도 동작)
2. 실패/false면 `Music` / `Spotify` AppleScript `player state` 조회 (`NSAppleEventsUsageDescription` Info.plist 필요 — 이미 추가됨)

YouTube(브라우저) 단독 재생 중일 때 isPlaying이 MediaRemote 1번에서 잡히지 않으면 AppleScript로도 감지 불가하여 no-op됨.

#### 재개 정책
`didPauseMedia` 플래그가 true일 때만 미디어 키 재발사. 사용자가 이미 일시정지였던 경우 건드리지 않음.

#### Race 방어
`pauseIfPlaying()`이 비동기 isPlaying 체크 중 `resumeIfPaused()`가 먼저 호출될 수 있음(매우 짧은 녹음). 내부 `pendingPause: Task`를 resume에서 await해 순서 보장.

#### 진단 로그
전 단계에 `NSLog("[MediaPlayback] ...")` — Console.app에서 `[MediaPlayback]` 검색으로 상태 체크/키 전송 경로 추적 가능.

### Dependencies
- `RecordingCoordinator` — 녹음 시작/종료/취소 시점에서 호출
- `AppSettings.pauseMediaDuringRecording` — 사용자 토글 (기본 true)
- `Info.plist`: `NSAppleEventsUsageDescription`
