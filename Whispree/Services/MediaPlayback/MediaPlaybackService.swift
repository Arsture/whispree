import AppKit
import Foundation

/// macOS 시스템 전역 미디어 재생 제어.
///
/// **전략 (layered)**:
/// 1. Music / Spotify: AppleScript로 직접 pause/play (가장 안정적, 권한 불요)
/// 2. 그 외 (YouTube/IINA/QuickTime 등): MediaRemote playing 감지 후
///    `NX_KEYTYPE_PLAY` 미디어 키 post (`.cghidEventTap`). macOS 26 Tahoe에서
///    `MRMediaRemoteSendCommand`가 non-Apple 프로세스에 대해 no-op이라 미디어 키
///    시뮬레이션으로 우회.
///
/// **Playing 감지 이중화**: `MRMediaRemoteGetNowPlayingApplicationIsPlaying`는
/// Chrome 같은 멀티프로세스 앱에서 main process 기준으로 false를 반환하고,
/// 실제 재생은 helper process에서 일어남. 이 갭을 메우기 위해 `MRMediaRemoteGetNowPlayingInfo`의
/// `kMRMediaRemoteNowPlayingInfoPlaybackRate`도 함께 조회 (> 0 이면 재생 중).
///
/// **중복 방지**: AppleScript로 Music/Spotify를 이미 pause한 경우 미디어 키를
/// 발사하지 않음. 미디어 키는 토글이므로 방금 pause한 Music/Spotify를 다시
/// 재생시킬 위험이 있기 때문.
///
/// **재개 정책**: 경로별로 기억해 대칭적으로 재개 (AppleScript로 pause → AppleScript로 play,
/// 미디어 키로 pause → 미디어 키로 resume). 사용자가 이미 정지 상태였던 앱은 건드리지 않음.
///
/// **Race 방어**: 비동기 체크 중 `resumeIfPaused()`가 먼저 호출되는 케이스를
/// 막기 위해 내부 `pendingPause` Task를 resume에서 await.
@MainActor
final class MediaPlaybackService {

    private typealias GetIsPlaying = @convention(c) (
        DispatchQueue, @escaping @convention(block) (Bool) -> Void
    ) -> Void

    private typealias GetNowPlayingInfo = @convention(c) (
        DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void
    ) -> Void

    private let getIsPlaying: GetIsPlaying?
    private let getNowPlayingInfo: GetNowPlayingInfo?

    private var pendingPause: Task<Void, Never>?
    private var pausedMusic = false
    private var pausedSpotify = false
    private var sentMediaKey = false

    init() {
        let url = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        guard let bundle = CFBundleCreate(kCFAllocatorDefault, url as CFURL) else {
            NSLog("[MediaPlayback] MediaRemote bundle load failed")
            self.getIsPlaying = nil
            self.getNowPlayingInfo = nil
            return
        }
        let playingPtr = CFBundleGetFunctionPointerForName(
            bundle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString
        )
        let infoPtr = CFBundleGetFunctionPointerForName(
            bundle, "MRMediaRemoteGetNowPlayingInfo" as CFString
        )
        self.getIsPlaying = playingPtr.map { unsafeBitCast($0, to: GetIsPlaying.self) }
        self.getNowPlayingInfo = infoPtr.map { unsafeBitCast($0, to: GetNowPlayingInfo.self) }
        NSLog("[MediaPlayback] ready (getIsPlaying=\(playingPtr != nil) getNowPlayingInfo=\(infoPtr != nil))")
    }

    /// 재생 중인 미디어 일시정지. fire-and-forget.
    func pauseIfPlaying() {
        guard pendingPause == nil else { return }
        pendingPause = Task { @MainActor [weak self] in
            guard let self else { return }

            // 1. Music / Spotify: AppleScript 직접 pause (권한 없이 가장 안정적)
            let apple = await Self.pauseAppleScriptPlayers()
            self.pausedMusic = apple.music
            self.pausedSpotify = apple.spotify
            guard !Task.isCancelled else { return }

            // 2. AppleScript로 pause한 것이 없을 때만 MediaRemote 체크 + 미디어 키
            // (이미 Music/Spotify를 pause했는데 또 미디어 키를 쏘면 토글되어 다시 재생됨)
            if !apple.music, !apple.spotify {
                let isPlayingAPI = await self.queryIsPlaying()
                // Chrome 같은 multi-process 앱은 isPlaying API가 main process 기준으로
                // false를 반환할 수 있으므로 playbackRate fallback 확인
                let playbackRate = isPlayingAPI ? 1.0 : await self.queryPlaybackRate()
                let playing = isPlayingAPI || playbackRate > 0
                NSLog("[MediaPlayback] MediaRemote isPlaying=\(isPlayingAPI) playbackRate=\(playbackRate) → playing=\(playing)")
                if playing {
                    Self.sendPlayPauseMediaKey()
                    self.sentMediaKey = true
                    NSLog("[MediaPlayback] media key sent (pause)")
                }
            }
        }
    }

    private func queryIsPlaying() async -> Bool {
        guard let fn = getIsPlaying else { return false }
        return await Self.queryMediaRemote(fn)
    }

    private func queryPlaybackRate() async -> Double {
        guard let fn = getNowPlayingInfo else { return 0 }
        return await Self.queryPlaybackRate(fn)
    }

    /// 우리가 pause한 경우에만 재개. pendingPause Task 완료 대기 후 경로별 대칭 재개.
    func resumeIfPaused() async {
        if let pending = pendingPause {
            _ = await pending.value
            pendingPause = nil
        }

        if pausedMusic {
            _ = await Self.runAppleScript("tell application \"Music\" to play")
            pausedMusic = false
            NSLog("[MediaPlayback] Music resumed")
        }
        if pausedSpotify {
            _ = await Self.runAppleScript("tell application \"Spotify\" to play")
            pausedSpotify = false
            NSLog("[MediaPlayback] Spotify resumed")
        }
        if sentMediaKey {
            Self.sendPlayPauseMediaKey()
            sentMediaKey = false
            NSLog("[MediaPlayback] media key sent (resume)")
        }
    }

    func reset() {
        pendingPause?.cancel()
        pendingPause = nil
        pausedMusic = false
        pausedSpotify = false
        sentMediaKey = false
    }

    // MARK: - AppleScript path

    nonisolated private static func pauseAppleScriptPlayers() async -> (music: Bool, spotify: Bool) {
        await withCheckedContinuation { (cont: CheckedContinuation<(music: Bool, spotify: Bool), Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var music = false
                var spotify = false

                let musicPerm = PermissionManager.queryAutomationStatus(bundleID: "com.apple.Music", askIfNeeded: false)
                if musicPerm != .denied, isRunning(app: "Music"),
                   applescriptBool("tell application \"Music\" to return (player state is playing)") {
                    _ = runAppleScriptSync("tell application \"Music\" to pause")
                    music = true
                    NSLog("[MediaPlayback] Music paused via AppleScript")
                }
                let spotifyPerm = PermissionManager.queryAutomationStatus(bundleID: "com.spotify.client", askIfNeeded: false)
                if spotifyPerm != .denied, isRunning(app: "Spotify"),
                   applescriptBool("tell application \"Spotify\" to return (player state is playing)") {
                    _ = runAppleScriptSync("tell application \"Spotify\" to pause")
                    spotify = true
                    NSLog("[MediaPlayback] Spotify paused via AppleScript")
                }
                cont.resume(returning: (music, spotify))
            }
        }
    }

    nonisolated private static func runAppleScript(_ source: String) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: runAppleScriptSync(source))
            }
        }
    }

    nonisolated private static func runAppleScriptSync(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var err: NSDictionary?
        _ = script.executeAndReturnError(&err)
        if let err {
            NSLog("[MediaPlayback] AppleScript run error: \(err)")
            return false
        }
        return true
    }

    nonisolated private static func applescriptBool(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var err: NSDictionary?
        let desc = script.executeAndReturnError(&err)
        if let err {
            NSLog("[MediaPlayback] AppleScript bool error: \(err)")
            return false
        }
        return desc.booleanValue
    }

    nonisolated private static func isRunning(app: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.localizedName == app }
    }

    // MARK: - MediaRemote detection

    private static func queryMediaRemote(_ fn: GetIsPlaying) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let lock = NSLock()
            var resumed = false
            fn(.main) { playing in
                lock.lock()
                defer { lock.unlock() }
                if resumed { return }
                resumed = true
                cont.resume(returning: playing)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                lock.lock()
                defer { lock.unlock() }
                if resumed { return }
                resumed = true
                NSLog("[MediaPlayback] MediaRemote isPlaying timeout")
                cont.resume(returning: false)
            }
        }
    }

    /// MRMediaRemoteGetNowPlayingInfo로 kMRMediaRemoteNowPlayingInfoPlaybackRate 조회.
    /// Chrome/Safari 같은 멀티프로세스 앱에서 isPlaying이 false를 반환할 때 fallback.
    private static func queryPlaybackRate(_ fn: GetNowPlayingInfo) async -> Double {
        await withCheckedContinuation { (cont: CheckedContinuation<Double, Never>) in
            let lock = NSLock()
            var resumed = false
            fn(.main) { info in
                lock.lock()
                defer { lock.unlock() }
                if resumed { return }
                resumed = true
                guard let info = info as? [String: Any] else {
                    cont.resume(returning: 0)
                    return
                }
                let rate = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
                cont.resume(returning: rate)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                lock.lock()
                defer { lock.unlock() }
                if resumed { return }
                resumed = true
                NSLog("[MediaPlayback] MediaRemote info timeout")
                cont.resume(returning: 0)
            }
        }
    }

    // MARK: - Media Key Event

    /// `NSEvent.systemDefined` subtype 8 (aux key) + NX_KEYTYPE_PLAY(16) 다운/업 페어.
    /// MediaKeyTap 등 오픈소스 라이브러리가 사용하는 표준 패턴. 시스템이 현재
    /// 활성 미디어 세션(YouTube 브라우저 탭, IINA 등)에 자동 라우팅.
    nonisolated private static func sendPlayPauseMediaKey() {
        let keyCode: Int = 16 // NX_KEYTYPE_PLAY
        for isDown in [true, false] {
            let flags: UInt = isDown ? 0xa00 : 0xb00
            let state: Int = isDown ? 0xa : 0xb
            let data1 = (keyCode << 16) | (state << 8)
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: flags),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { continue }
            event.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}
