import AppKit

/// 녹음 시작 전 유저가 있던 위치.
///
/// - `.app` — 일반 앱 (activateApp + Cmd+V)
/// - `.chromeTab` — Chrome 특화. `BrowserContextService.restoreChrome`이 탭 전환 + element focus + 커서 복원.
/// - `.iTerm2Session` — iTerm2 특화. `TerminalContextService.restoreITerm2`이 session(pane) 활성화 + tmux 페인 선택.
enum ExternalContext {
    case app(NSRunningApplication)
    case chromeTab(
        app: NSRunningApplication,
        windowIndex: Int,
        tabIndex: Int,
        tabID: Int,
        tabURL: String,
        element: ElementInfo?
    )
    case iTerm2Session(
        app: NSRunningApplication,
        sessionID: String,
        tty: String,
        tmux: TmuxSnapshot?
    )

    var app: NSRunningApplication {
        switch self {
            case .app(let a): return a
            case .chromeTab(let a, _, _, _, _, _): return a
            case .iTerm2Session(let a, _, _, _): return a
        }
    }

    var isChromeTab: Bool {
        if case .chromeTab = self {
            return true
        }
        return false
    }
}

/// 포커스된 element의 selector + 커서 위치.
/// - `type`: "input" (input/textarea — selectionStart/End 기반) | "ce" (contenteditable — 문자 offset 기반)
/// - `start`/`end`: input은 `selectionStart`/`selectionEnd`. ce는 contenteditable root 기준 **문자 offset**(fallback용).
/// - `startPath`/`endPath` + node offset: ce에서 빈 paragraph/BR처럼 문자 offset만으로 표현 안 되는 caret 위치를 정확히 복원.
struct ElementInfo: Equatable {
    let selector: String
    let type: String
    let start: Int
    let end: Int
    /// contenteditable selection start container path from root via childNodes indexes.
    /// Unlike text offsets, this can represent empty paragraphs/BR positions.
    let startPath: String?
    /// contenteditable selection end container path from root via childNodes indexes.
    let endPath: String?
    /// contenteditable selection start offset inside `startPath` node.
    let startNodeOffset: Int?
    /// contenteditable selection end offset inside `endPath` node.
    let endNodeOffset: Int?

    init(
        selector: String,
        type: String,
        start: Int,
        end: Int,
        startPath: String? = nil,
        endPath: String? = nil,
        startNodeOffset: Int? = nil,
        endNodeOffset: Int? = nil
    ) {
        self.selector = selector
        self.type = type
        self.start = start
        self.end = end
        self.startPath = startPath
        self.endPath = endPath
        self.startNodeOffset = startNodeOffset
        self.endNodeOffset = endNodeOffset
    }
}

/// iTerm2 pane 안에서 tmux가 돌고 있을 때 그 내부 위치.
/// - `socketPath`: nil = 기본 소켓(tmux 인자 없이 호출). 커스텀 `-L`/`-S` 소켓은 MVP 범위 밖.
/// - `sessionName`/`windowIndex`/`paneIndex`: `tmux display -p '#S #I #P'` 원본값.
struct TmuxSnapshot: Equatable {
    let socketPath: String?
    let sessionName: String
    let windowIndex: Int
    let paneIndex: Int
}
