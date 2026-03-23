import AppKit
import ApplicationServices

final class TextInsertionService {

    func insertText(_ text: String, targetApp: NSRunningApplication? = nil) async -> Bool {
        // 유효한 외부 앱이 있으면 활성화 + Cmd+V
        if let target = targetApp,
           target.bundleIdentifier != Bundle.main.bundleIdentifier {
            target.activate()
            // 앱 활성화 대기 (async — MainActor 블로킹 방지)
            let deadline = Date().addingTimeInterval(0.5)
            while NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier,
                  Date() < deadline {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
            return await insertViaClipboard(text)
        }

        // target 없음 (Settings에서 녹음 등) → 클립보드에만 복사, Cmd+V 안 함
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        return false
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
