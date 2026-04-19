import AppKit
import Foundation
import OSLog

/// iTerm2 + (선택적) tmux 컨텍스트 캡처/복원.
///
/// - `captureITerm2`: front iTerm2 window의 active session UUID + tty 저장. tty 기반으로 tmux client
///   매칭 시도 → 찾으면 현재 attached 상태의 `session:window.pane` 캡처.
/// - `restoreITerm2`: iTerm2를 앞으로 + 전 windows/tabs/sessions 순회하며 UUID 매칭 pane select.
///   tmux 스냅샷이 있으면 `tmux select-window` + `select-pane`으로 내부 pane도 복원.
///
/// 필요한 시스템 권한:
/// 1. **Automation** — `NSAppleScript`로 iTerm2 제어. 첫 호출 시 macOS가 자동 프롬프트.
/// 2. (tmux 사용자 한정) `tmux` 바이너리 PATH 접근 — Process 실행으로 shell-out.
@MainActor
final class TerminalContextService {

    static let iTerm2BundleID = "com.googlecode.iterm2"
    static let logger = Logger(subsystem: "com.whispree.app", category: "TerminalContext")

    static func isITerm2(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == iTerm2BundleID
    }

    /// 현재 iTerm2 컨텍스트 캡처. 실패 시 `.app(app)` fallback.
    func captureITerm2(app: NSRunningApplication) -> ExternalContext {
        Self.logger.info("captureITerm2: start — bundle=\(app.bundleIdentifier ?? "nil", privacy: .public)")
        guard let captured = Self.runCaptureSession() else {
            Self.logger.error("captureITerm2: runCaptureSession nil — falling back to .app")
            return .app(app)
        }
        Self.logger.info(
            "captureITerm2: sessionID=\(captured.sessionID, privacy: .public) tty=\(captured.tty, privacy: .public)"
        )

        let tmux = Self.captureTmux(clientTty: captured.tty)
        if let tmux = tmux {
            Self.logger.info(
                "captureITerm2: tmux attached — \(tmux.sessionName, privacy: .public):\(tmux.windowIndex).\(tmux.paneIndex)"
            )
        } else {
            Self.logger.info("captureITerm2: no tmux client for tty")
        }

        return .iTerm2Session(
            app: app,
            sessionID: captured.sessionID,
            tty: captured.tty,
            tmux: tmux
        )
    }

    /// `.iTerm2Session` 컨텍스트 기반 복원. iTerm2 앞으로 + session select (+ tmux pane).
    func restoreITerm2(_ ctx: ExternalContext) -> Bool {
        guard case let .iTerm2Session(_, sessionID, _, tmux) = ctx else {
            return false
        }
        Self.logger.info("restoreITerm2: start — sessionID=\(sessionID, privacy: .public)")

        let sessionRestored = Self.runRestoreSession(sessionID: sessionID)
        guard sessionRestored else {
            Self.logger.error("restoreITerm2: session restore failed")
            return false
        }

        if let tmux = tmux {
            let ok = Self.runRestoreTmux(tmux)
            Self.logger.info(
                "restoreITerm2: tmux \(tmux.sessionName, privacy: .public):\(tmux.windowIndex).\(tmux.paneIndex) → \(ok ? "ok" : "fail", privacy: .public)"
            )
        }
        return true
    }

    // MARK: - AppleScript runners (MainActor — TCC 프롬프트는 메인 스레드에서만 표시됨)

    private static func runCaptureSession() -> (sessionID: String, tty: String)? {
        guard let raw = executeScript(ITerm2AppleScripts.captureActiveSession),
              !raw.isEmpty
        else { return nil }
        let parts = raw.components(separatedBy: "|::|")
        guard parts.count >= 2, !parts[0].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    private static func runRestoreSession(sessionID: String) -> Bool {
        executeScript(ITerm2AppleScripts.restoreSession(sessionID: sessionID)) == "ok"
    }

    private static func executeScript(_ source: String) -> String? {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            logger.error("AppleScript init failed")
            return nil
        }
        let output = script.executeAndReturnError(&errorInfo)
        if let errorInfo = errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            let msg = (errorInfo[NSAppleScript.errorMessage] as? String) ?? "?"
            logger.error("AppleScript error \(code) \(msg, privacy: .public)")
            return nil
        }
        return output.stringValue
    }

    // MARK: - tmux (shell-out)
    //
    // iTerm2 session의 tty에 attach된 tmux client를 기본 소켓에서 찾아 active pane 위치 캡처.
    // `tmux list-clients -F '#{client_tty} #{session_name}'` → tty 매칭 → attached session.
    // `tmux display-message -p -F '#I #P' -t <session>` → active window/pane.

    /// iTerm session tty에 attach된 tmux 찾기 → attached session의 active window/pane 반환.
    private static func captureTmux(clientTty: String) -> TmuxSnapshot? {
        guard let tmuxPath = findTmuxBinary() else {
            logger.debug("captureTmux: tmux binary not found in PATH")
            return nil
        }
        // tmux는 tty path를 `/dev/ttys001` 형태 그대로 출력 (macOS).
        guard let clientsRaw = runShell(tmuxPath, args: ["list-clients", "-F", "#{client_tty} #{session_name}"]),
              !clientsRaw.isEmpty
        else { return nil }

        var matchedSession: String?
        for line in clientsRaw.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let tty = String(parts[0])
            let session = String(parts[1])
            if tty == clientTty || tty.hasSuffix(clientTty) || clientTty.hasSuffix(tty) {
                matchedSession = session
                break
            }
        }
        guard let session = matchedSession else {
            logger.debug("captureTmux: no tmux client matched tty \(clientTty, privacy: .public)")
            return nil
        }

        guard let paneRaw = runShell(tmuxPath, args: ["display-message", "-p", "-F", "#I #P", "-t", session]),
              !paneRaw.isEmpty
        else { return nil }
        let paneParts = paneRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard paneParts.count >= 2,
              let winIdx = Int(paneParts[0]),
              let paneIdx = Int(paneParts[1])
        else { return nil }

        return TmuxSnapshot(
            socketPath: nil,
            sessionName: session,
            windowIndex: winIdx,
            paneIndex: paneIdx
        )
    }

    /// tmux 상태 복원: select-window → select-pane.
    private static func runRestoreTmux(_ snap: TmuxSnapshot) -> Bool {
        guard let tmuxPath = findTmuxBinary() else { return false }
        let winTarget = "\(snap.sessionName):\(snap.windowIndex)"
        let paneTarget = "\(winTarget).\(snap.paneIndex)"
        _ = runShell(tmuxPath, args: ["select-window", "-t", winTarget])
        _ = runShell(tmuxPath, args: ["select-pane", "-t", paneTarget])
        return true
    }

    /// tmux 바이너리 탐색 — 앱이 상속받은 PATH가 GUI 런치 컨텍스트라 Homebrew 경로 누락 가능.
    /// Apple Silicon / Intel / system 순으로 확인. 캐싱은 안 함 (호출 빈도 낮음, 유저가 tmux 설치/삭제 가능).
    private static func findTmuxBinary() -> String? {
        let candidates = [
            "/opt/homebrew/bin/tmux",
            "/usr/local/bin/tmux",
            "/usr/bin/tmux",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// `Process` 래퍼. stdout trim. 비정상 종료/실패면 nil.
    private static func runShell(_ executable: String, args: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            logger.error("runShell launch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
