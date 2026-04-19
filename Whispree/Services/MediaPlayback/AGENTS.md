# MediaPlayback

## Purpose
macOS 시스템 전역 미디어 재생 제어. 녹음 시작 시 재생 중인 음악/영상을 일시정지하고 녹음 종료 시 재개.

## Key Files

| File | Description |
|------|-------------|
| `MediaPlaybackService.swift` | `@MainActor` — AppleScript(Music/Spotify) + MediaRemoteAdapter Perl subprocess(나머지) + 미디어 키 fallback |

## 왜 이 방식인가 (macOS 15.4+ 대응)

Apple은 macOS 15.4부터 `mediaremoted` 데몬에서 번들 ID 검증을 추가하여 `com.apple.*`이 아닌 앱이 `MRMediaRemoteGetNowPlayingInfo` / `MRMediaRemoteSendCommand`를 호출하면 `kMRMediaRemoteFrameworkErrorDomain Code=3 "Operation not permitted"`를 반환. 제3자 앱에서 직접 호출하는 경로는 완전히 차단됨.

**우회**: `/usr/bin/perl` (번들 ID `com.apple.perl5`)이 여전히 엔타이틀먼트를 보유하므로, 앱 번들에 포함한 `MediaRemoteAdapter.framework`를 perl subprocess가 dyld로 로드하게 하는 방식 ([ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)).

**리스크**: Apple이 언젠가 perl의 엔타이틀먼트도 제거하면 이 경로도 깨짐. 그래서 `sendPlayPauseMediaKey()` 미디어 키 fallback을 유지.

## Layered Strategy

1. **Music / Spotify**: AppleScript 직접 pause/play (`com.apple.security.automation.apple-events` entitlement 필요, 이미 설정). 가장 안정적.
2. **그 외 앱 (YouTube/IINA/QuickTime 등)**: MediaRemoteAdapter Perl subprocess로 `get`(상태 조회) → `send 1`(kMRPause). 명시적 pause라 "토글이 아님" — 이미 정지된 앱을 재생시킬 위험 없음.
3. **Fallback**: adapter 호출 실패 시 `NX_KEYTYPE_PLAY` 미디어 키 post (토글).

## 번들 구성

`Whispree/Vendor/MediaRemoteAdapter/`에 source 보관, `project.yml` postBuildScript가 빌드 시 `Contents/Resources/MediaRemoteAdapter/`로 복사:
- `MediaRemoteAdapter.framework/` — dyld 로드 전용 (linked against 하지 않음)
- `MediaRemoteAdapterTestClient` — (선택) `test` 커맨드용 헬퍼
- `mediaremote-adapter.pl` — Perl 진입점
- `LICENSE` — BSD 3-Clause

Adapter 업그레이드 시: 원본 repo `cmake --build .` 후 빌드 산출물을 `Whispree/Vendor/MediaRemoteAdapter/`에 덮어쓰기.

## 재개 정책

pause 경로별로 플래그 추적 (`pausedMusic`, `pausedSpotify`, `pausedViaAdapter`, `sentMediaKey`) → resume 시 대칭적으로 역호출. 사용자가 이미 정지였던 앱은 건드리지 않음.

## Race 방어

`pauseIfPlaying()`이 비동기 중 `resumeIfPaused()`가 먼저 호출될 수 있음. 내부 `pendingPause: Task`를 resume에서 await해 순서 보장.

## 진단 로그

- `NSLog("[MediaPlayback] ...")` — Console.app에서 `[MediaPlayback]` 검색
- Adapter 전용 로그: `process == "perl"` 필터 (subprocess가 stderr에 출력)

## Dependencies

- `RecordingCoordinator` — 녹음 시작/종료/취소 시점에서 호출
- `AppSettings.pauseMediaDuringRecording` — 사용자 토글 (기본 true)
- `PermissionManager.queryAutomationStatus` — Music/Spotify AppleScript 권한 체크
- `Info.plist`: `NSAppleEventsUsageDescription`
- Entitlements: `com.apple.security.automation.apple-events`
