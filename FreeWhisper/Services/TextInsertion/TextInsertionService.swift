import AppKit
import ApplicationServices

final class TextInsertionService {

    func insertText(_ text: String, targetApp: NSRunningApplication? = nil) -> Bool {
        // Always use clipboard + Cmd+V — most reliable across all apps
        // First, make sure the target app is in front
        if let target = targetApp,
           target.bundleIdentifier != Bundle.main.bundleIdentifier {
            target.activate()
            // Wait for app to actually come to front
            let deadline = Date().addingTimeInterval(0.5)
            while NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier,
                  Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }

        return insertViaClipboard(text)
    }

    // MARK: - Clipboard + Cmd+V

    private func insertViaClipboard(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let previousContents = pasteboard.string(forType: .string)

        // Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is ready
        Thread.sleep(forTimeInterval: 0.05)

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

        // Restore clipboard after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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
