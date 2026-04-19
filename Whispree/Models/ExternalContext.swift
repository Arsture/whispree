import AppKit

/// 녹음 시작 전 유저가 있던 위치. Chrome 탭은 window+tab+id+URL + element selector + 커서 위치 캡처.
///
/// `.app` — 일반 앱 (activateApp + Cmd+V)
/// `.chromeTab` — Chrome 특화. `BrowserContextService.restoreChrome`이 탭 전환 + element focus + 커서 복원.
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

    var app: NSRunningApplication {
        switch self {
            case .app(let a): return a
            case .chromeTab(let a, _, _, _, _, _): return a
        }
    }
}

/// 포커스된 element의 selector + 커서 위치.
/// - `type`: "input" (input/textarea — selectionStart/End 기반) | "ce" (contenteditable — 문자 offset 기반)
/// - `start`/`end`: input은 `selectionStart`/`selectionEnd`. ce는 contenteditable root 기준 **문자 offset**.
struct ElementInfo: Equatable {
    let selector: String
    let type: String
    let start: Int
    let end: Int
}
