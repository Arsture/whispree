import Foundation

/// iTerm2 제어용 AppleScript 템플릿 모음.
///
/// iTerm2는 각 pane(split)을 **session**으로 모델링하며, 각 session은 고유한 `unique id` (UUID) 보유.
/// → "지금 유저가 있던 pane"을 가장 신뢰성 있게 식별하는 키.
/// window ID/tab index는 pane이 이동/재배치되면 변하지만 session UUID는 앱 재시작 전까지 안정.
enum ITerm2AppleScripts {

    /// 현재 front iTerm2 window의 active session의 UUID + tty path를 "|::|"로 구분 반환.
    /// tty는 그 session 안에서 tmux 돌고 있는지 감지하는 데 사용 (`tmux list-clients`의 client_tty와 매칭).
    /// window 없으면 빈 문자열.
    static let captureActiveSession = """
    tell application "iTerm2"
        if (count of windows) = 0 then return ""
        tell current window
            tell current session
                set sid to unique id
                set ttyPath to tty
                return (sid as string) & "|::|" & (ttyPath as string)
            end tell
        end tell
    end tell
    """

    /// 저장된 session UUID를 가진 pane을 전체 windows/tabs/sessions에서 찾아 select.
    /// iTerm2 AppleScript: `select` 동사는 window/tab/session 모두 지원 → 각 단계에서 호출하면 정확히 해당 pane으로 포커스 이동.
    /// 성공 "ok", 못 찾으면 "notfound", 창 없으면 "nowindow".
    static func restoreSession(sessionID: String) -> String {
        let escSID = escapeForAppleScript(sessionID)
        return """
        tell application "iTerm2"
            activate
            if (count of windows) = 0 then return "nowindow"
            set targetID to "\(escSID)"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if (unique id of s) as string is equal to targetID then
                            select w
                            tell w to select t
                            tell t to select s
                            return "ok"
                        end if
                    end repeat
                end repeat
            end repeat
            return "notfound"
        end tell
        """
    }

    // MARK: - Escaping

    private static func escapeForAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
