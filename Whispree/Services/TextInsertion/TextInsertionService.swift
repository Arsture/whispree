import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class TextInsertionService {
    func insertText(_ text: String, targetApp: NSRunningApplication? = nil) async -> Bool {
        // 유효한 외부 앱이 있으면 활성화 + Cmd+V
        if let target = targetApp,
           target.bundleIdentifier != Bundle.main.bundleIdentifier
        {
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
                      Date() < deadline
                {
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
                  Date() < deadline
            {
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
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
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

    // MARK: - Image Paste

    /// 캡처된 스크린샷들을 대상 앱에 이미지로 순서대로 붙여넣기
    /// 각 이미지마다: 클립보드에 이미지 복사 → Cmd+V → 영어 입력소스 전환 → Ctrl+V → 입력소스 복원
    func insertImages(_ images: [Data], targetApp: NSRunningApplication? = nil) async {
        guard !images.isEmpty else { return }

        // 대상 앱이 이미 활성화되어 있어야 함 (텍스트 삽입 후 호출되므로 보통 이미 활성 상태)
        if let target = targetApp,
           target.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            let isFront = NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
            if !isFront {
                _ = await activateApp(target)
            }
        }

        for imageData in images {
            // 클립보드에 이미지 복사
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            guard let image = NSImage(data: imageData) else { continue }
            pasteboard.writeObjects([image])

            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms — 클립보드 안정화

            // Cmd+V (브라우저 등에서 작동)
            sendPasteKey(flags: .maskCommand)

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초

            // 영어 입력소스로 전환 → Ctrl+V → 원래 입력소스 복원
            let originalSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
            switchToASCIIInputSource()

            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms — 입력소스 전환 안정화

            sendPasteKey(flags: .maskControl)

            // 원래 입력소스 복원
            TISSelectInputSource(originalSource)

            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2초 — 다음 이미지 전 대기
        }
    }

    /// CGEvent로 V키 + 지정 modifier 전송
    private func sendPasteKey(flags: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else { return }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    /// ASCII 입력 가능한 입력 소스(영어)로 전환
    private func switchToASCIIInputSource() {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return }
        for source in sources {
            guard let categoryRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) else { continue }
            let category = Unmanaged<CFString>.fromOpaque(categoryRef).takeUnretainedValue() as String
            guard category == kTISCategoryKeyboardInputSource as String else { continue }

            guard let asciiRef = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else { continue }
            let isASCII = Unmanaged<CFBoolean>.fromOpaque(asciiRef).takeUnretainedValue()
            if CFBooleanGetValue(isASCII) {
                TISSelectInputSource(source)
                return
            }
        }
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
