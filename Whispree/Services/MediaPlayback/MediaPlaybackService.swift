import AppKit
import Foundation

/// macOS 시스템 전역 미디어 재생 제어.
///
/// **전략 (layered)**:
/// 1. Music / Spotify: AppleScript로 직접 pause/play (가장 안정적, 권한 불요)
/// 2. 그 외 (YouTube/IINA/QuickTime 등): MediaRemote private framework을 통한 명시적
///    `kMRPause` / `kMRPlay` 명령. macOS 15.4+에서 Apple이 non-Apple 프로세스의
///    MediaRemote 접근을 차단했지만 `/usr/bin/perl` (번들 ID `com.apple.perl5`)은
///    여전히 엔타이틀먼트를 보유하므로, 번들된 `MediaRemoteAdapter.framework` +
///    `mediaremote-adapter.pl` subprocess로 우회. (출처: ungive/mediaremote-adapter)
/// 3. Perl adapter 호출 실패 시 `NX_KEYTYPE_PLAY` 미디어 키 fallback.
///
/// **재개 정책**: 경로별로 기억해 대칭적으로 재개 (AppleScript로 pause → AppleScript로 play,
/// adapter로 pause → adapter로 play, 미디어 키로 pause → 미디어 키로 resume).
/// 사용자가 이미 정지 상태였던 앱은 건드리지 않음.
///
/// **Race 방어**: 비동기 체크 중 `resumeIfPaused()`가 먼저 호출되는 케이스를
/// 막기 위해 내부 `pendingPause` Task를 resume에서 await.
@MainActor
final class MediaPlaybackService {

    private var pendingPause: Task<Void, Never>?
    private var pausedMusic = false
    private var pausedSpotify = false
    private var pausedViaAdapter = false
    private var sentMediaKey = false

    /// 재생 중인 미디어 일시정지. fire-and-forget.
    func pauseIfPlaying() {
        guard pendingPause == nil else { return }
        pendingPause = Task { @MainActor [weak self] in
            guard let self else { return }

            // 1. Music / Spotify: AppleScript 직접 pause
            let apple = await Self.pauseAppleScriptPlayers()
            self.pausedMusic = apple.music
            self.pausedSpotify = apple.spotify
            guard !Task.isCancelled else { return }

            // 2. 그 외 앱: MediaRemote adapter로 명시적 pause
            if !apple.music, !apple.spotify {
                let info = await Self.adapterGetNowPlaying()
                if let info, info.isPlaying {
                    NSLog("[MediaPlayback] adapter detected playing app=\(info.bundleId ?? "?")")
                    let ok = await Self.adapterSend(command: .pause)
                    if ok {
                        self.pausedViaAdapter = true
                        NSLog("[MediaPlayback] pause command sent via adapter")
                    } else {
                        // adapter 명령 실패 → 미디어 키 fallback
                        Self.sendPlayPauseMediaKey()
                        self.sentMediaKey = true
                        NSLog("[MediaPlayback] adapter send failed, fallback to media key")
                    }
                } else {
                    NSLog("[MediaPlayback] adapter reports nothing playing (info=\(info != nil))")
                }
            }
        }
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
        if pausedViaAdapter {
            _ = await Self.adapterSend(command: .play)
            pausedViaAdapter = false
            NSLog("[MediaPlayback] adapter play command sent")
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
        pausedViaAdapter = false
        sentMediaKey = false
    }

    // MARK: - AppleScript path (Music / Spotify)

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

    // MARK: - MediaRemote adapter path (Perl subprocess)

    /// MediaRemote 명령 ID. README 참조.
    private enum AdapterCommand: Int {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
    }

    struct NowPlayingInfo {
        let bundleId: String?
        let title: String?
        let isPlaying: Bool
    }

    nonisolated private static func adapterResourcePath(_ name: String) -> String? {
        guard let resourceDir = Bundle.main.resourcePath else { return nil }
        let path = (resourceDir as NSString).appendingPathComponent("MediaRemoteAdapter/\(name)")
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    nonisolated private static func adapterGetNowPlaying() async -> NowPlayingInfo? {
        guard let script = adapterResourcePath("mediaremote-adapter.pl"),
              let framework = adapterResourcePath("MediaRemoteAdapter.framework") else {
            NSLog("[MediaPlayback] adapter resources missing")
            return nil
        }

        return await withCheckedContinuation { (cont: CheckedContinuation<NowPlayingInfo?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
                proc.arguments = [script, framework, "get"]
                let outPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = FileHandle.nullDevice
                do {
                    try proc.run()
                } catch {
                    NSLog("[MediaPlayback] adapter launch failed: \(error)")
                    cont.resume(returning: nil)
                    return
                }
                // stdout을 EOF까지 읽어 파이프 드레인 (artwork base64로 200KB+).
                // 읽기 전에 wait하면 파이프 버퍼 full 시 Perl이 block되어 hang 발생.
                let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()

                guard proc.terminationStatus == 0 else {
                    NSLog("[MediaPlayback] adapter get exit=\(proc.terminationStatus)")
                    cont.resume(returning: nil)
                    return
                }
                guard let json = try? JSONSerialization.jsonObject(with: data),
                      let dict = json as? [String: Any] else {
                    // "null" 또는 빈 출력 = 현재 Now Playing 없음
                    cont.resume(returning: nil)
                    return
                }
                let info = NowPlayingInfo(
                    bundleId: dict["bundleIdentifier"] as? String,
                    title: dict["title"] as? String,
                    isPlaying: (dict["playing"] as? Bool) ?? false
                )
                cont.resume(returning: info)
            }
        }
    }

    nonisolated private static func adapterSend(command: AdapterCommand) async -> Bool {
        guard let script = adapterResourcePath("mediaremote-adapter.pl"),
              let framework = adapterResourcePath("MediaRemoteAdapter.framework") else {
            return false
        }
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
                proc.arguments = [script, framework, "send", String(command.rawValue)]
                // send 커맨드는 출력이 거의 없지만 파이프 블로킹 방지 위해 /dev/null로 리다이렉트.
                proc.standardOutput = FileHandle.nullDevice
                proc.standardError = FileHandle.nullDevice
                do {
                    try proc.run()
                } catch {
                    NSLog("[MediaPlayback] adapter send launch failed: \(error)")
                    cont.resume(returning: false)
                    return
                }
                proc.waitUntilExit()
                cont.resume(returning: proc.terminationStatus == 0)
            }
        }
    }

    // MARK: - Media Key Event (fallback)

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
