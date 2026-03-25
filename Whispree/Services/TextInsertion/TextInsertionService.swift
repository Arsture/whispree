import AppKit
import ApplicationServices

final class TextInsertionService {

    func insertText(_ text: String, targetApp: NSRunningApplication? = nil) async -> Bool {
        // 유효한 외부 앱이 있으면 활성화 + Cmd+V
        if let target = targetApp,
           target.bundleIdentifier != Bundle.main.bundleIdentifier {
            let activated = await activateApp(target)

            if !activated {
                // 활성화 실패 — 클립보드에만 복사, Cmd+V 안 쏨
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                return false
            }

            return await insertViaClipboard(text)
        }

        // target 없음 (Settings에서 녹음 등) → 클립보드에만 복사, Cmd+V 안 함
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return false
    }

    // MARK: - App Activation

    /// 대상 앱을 강제 활성화. NSWorkspace.openApplication → activate() 폴백.
    private func activateApp(_ target: NSRunningApplication) async -> Bool {
        // 방법 1: NSWorkspace.openApplication (가장 신뢰성 높음)
        if let bundleURL = target.bundleURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            do {
                _ = try await NSWorkspace.shared.openApplication(at: bundleURL, configuration: config)
                // 활성화 대기
                let deadline = Date().addingTimeInterval(1.0)
                while NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier,
                      Date() < deadline {
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                }
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
                    return true
                }
            } catch {
                // openApplication 실패 시 activate() 폴백으로 진행
            }
        }

        // 방법 2: activate() 폴백
        let activated = target.activate()
        if activated {
            let deadline = Date().addingTimeInterval(0.5)
            while NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier,
                  Date() < deadline {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
    }

    // MARK: - Clipboard + Cmd+V

    private func insertViaClipboard(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let previousContents = pasteboard.string(forType: .string)

        // Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is ready (async — MainActor yield)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .combinedSessionState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        // Restore clipboard after delay (async, non-blocking)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            pasteboard.clearContents()
            if let previous = previousContents {
                pasteboard.setString(previous, forType: .string)
            }
        }

        return true
    }

    // MARK: - Permission Check

    static func isAccessibilityEnabled() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(options)
    }
}
