import AppKit
import Foundation
import OSLog

/// Chrome 전용 탭/input element 컨텍스트 캡처 + 복원.
///
/// - `captureChrome`: 현재 front Chrome의 window/tab/id/URL + active element CSS selector 저장.
/// - `restoreChrome`: 저장된 컨텍스트로 탭 전환 + element focus. JS 미허용 시 탭만 복원.
///
/// 필요한 시스템 권한:
/// 1. **Automation** (System Settings → Privacy & Security → Automation → Whispree → Google Chrome)
///    — `NSAppleScript` → Chrome 제어. 첫 호출 시 macOS가 자동 프롬프트.
/// 2. **Apple Events로부터 JavaScript 허용** (Chrome 메뉴바 → 보기 → 개발자)
///    — element 복원에만 필요. 미허용 시 selector = nil로 graceful fallback.
@MainActor
final class BrowserContextService {

    static let chromeBundleID = "com.google.Chrome"
    static let logger = Logger(subsystem: "com.whispree.app", category: "BrowserContext")

    static func isChrome(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == chromeBundleID
    }

    /// 활성 Chrome 탭의 컨텍스트 캡처. AppleScript 호출은 detached Task에서 실행 (100–300ms 지연 흡수).
    /// 실패 시 `.app(app)` fallback.
    func captureChrome(app: NSRunningApplication) -> ExternalContext {
        Self.logger.info("captureChrome: start — bundle=\(app.bundleIdentifier ?? "nil", privacy: .public)")
        guard let captured = Self.runCapture() else {
            Self.logger.error("captureChrome: runCapture returned nil — falling back to .app")
            return .app(app)
        }
        Self.logger.info("captureChrome: captured window=\(captured.windowIndex) tab=\(captured.tabIndex) id=\(captured.tabID)")

        // JS element info는 optional — "Apple Events로부터 JavaScript 허용" 꺼져있어도 탭 복원은 가능
        let element = Self.runComputeElement()
        if let element = element {
            Self.logger.info(
                "captureChrome: element selector=\(element.selector, privacy: .public) type=\(element.type, privacy: .public) start=\(element.start) end=\(element.end)"
            )
        } else {
            Self.logger.info("captureChrome: element=<none>")
        }

        return .chromeTab(
            app: app,
            windowIndex: captured.windowIndex,
            tabIndex: captured.tabIndex,
            tabID: captured.tabID,
            tabURL: captured.tabURL,
            element: element
        )
    }

    /// `.chromeTab` 컨텍스트 기반 복원. 탭 복원 성공 시 true (element focus는 best effort).
    func restoreChrome(_ ctx: ExternalContext) -> Bool {
        guard case let .chromeTab(_, _, _, tabID, tabURL, element) = ctx else {
            return false
        }
        Self.logger.info("restoreChrome: start — tabID=\(tabID) url=\(tabURL, privacy: .public)")

        let tabRestored = Self.runRestoreTab(tabID: tabID, fallbackURL: tabURL)
        guard tabRestored else {
            Self.logger.error("restoreChrome: tab restore failed")
            return false
        }

        if let element = element, !element.selector.isEmpty {
            let focused = Self.runFocusElement(element)
            Self.logger.info(
                "restoreChrome: focus \(element.type, privacy: .public) start=\(element.start) end=\(element.end) → \(focused ? "ok" : "fail", privacy: .public)"
            )
        }

        return true
    }

    // MARK: - AppleScript runners (MainActor — TCC 프롬프트는 메인 스레드에서만 표시됨)
    //
    // Task.detached로 배경 스레드에서 NSAppleScript를 실행하면 macOS가 -1743을 조용히 반환하고
    // Automation 권한 프롬프트를 띄우지 않음. 반드시 MainActor에서 직접 실행해야 함.

    private static func runCapture() -> (windowIndex: Int, tabIndex: Int, tabID: Int, tabURL: String)? {
        guard let raw = executeScript(ChromeAppleScripts.captureActiveTab),
              !raw.isEmpty
        else { return nil }
        let parts = raw.components(separatedBy: "|::|")
        guard parts.count >= 4,
              let winIdx = Int(parts[0]),
              let tabIdx = Int(parts[1]),
              let tabID = Int(parts[2])
        else { return nil }
        return (winIdx, tabIdx, tabID, parts[3])
    }

    /// `selector|::|type|::|start|::|end` 포맷 파싱. selector 빈 문자열이면 nil.
    private static func runComputeElement() -> ElementInfo? {
        guard let raw = executeScript(ChromeAppleScripts.captureActiveElement),
              !raw.isEmpty
        else { return nil }
        let parts = raw.components(separatedBy: "|::|")
        guard parts.count >= 4, !parts[0].isEmpty else { return nil }
        let selector = parts[0]
        let type = parts[1]
        let start = Int(parts[2]) ?? 0
        let end = Int(parts[3]) ?? start
        return ElementInfo(selector: selector, type: type, start: start, end: end)
    }

    private static func runRestoreTab(tabID: Int, fallbackURL: String) -> Bool {
        executeScript(ChromeAppleScripts.restoreTab(tabID: tabID, fallbackURL: fallbackURL)) == "ok"
    }

    private static func runFocusElement(_ info: ElementInfo) -> Bool {
        executeScript(
            ChromeAppleScripts.focusElement(
                selector: info.selector,
                type: info.type,
                start: info.start,
                end: info.end
            )
        ) == "ok"
    }

    /// NSAppleScript 동기 실행. error 발생 시 nil 반환. MainActor에서만 호출 — TCC 프롬프트 조건.
    /// -1743: Automation 권한 거부. -1728/-1708 계열: JS 미허용 또는 실행 실패.
    private static func executeScript(_ source: String) -> String? {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            logger.error("AppleScript init failed (source too long or invalid)")
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
}
