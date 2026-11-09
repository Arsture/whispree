import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class TextInsertionService {
    /// 붙여넣기 전 사용자의 실제 키 입력이 이만큼 멈춰 있어야 한다.
    static let keyboardIdleGap: TimeInterval = 0.5
    /// 계속 타이핑 중이어도 이 시간이 지나면 붙여넣는다 (FIFO delivery를 무한정 막지 않기 위해).
    static let keyboardIdleMaxWait: TimeInterval = 3.0

    /// 사용자가 키보드를 치는 중이면 멈출 때까지 기다린다.
    /// 타이핑(특히 한글 조합) 도중에 합성 Cmd+V가 끼어들면 조합 글자와 엉켜 붙여넣기가 깨진다.
    /// hidSystemState는 실제 하드웨어 입력만 반영하므로 Whispree가 보낸 합성 이벤트는 영향을 주지 않는다.
    func waitForKeyboardIdle() async {
        let deadline = Date().addingTimeInterval(Self.keyboardIdleMaxWait)
        let heldModifiers: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        while Date() < deadline {
            let sinceKey = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .keyDown)
            let modifiersHeld = !CGEventSource.flagsState(.hidSystemState).intersection(heldModifiers).isEmpty
            if sinceKey >= Self.keyboardIdleGap, !modifiersHeld { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

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

        // 받아쓰기 결과는 클립보드에 그대로 남긴다 (이전 내용 복원 안 함).
        // 붙여넣기가 실패해도 사용자가 직접 Cmd+V로 쓸 수 있다.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is ready (async — MainActor yield)
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        await waitForKeyboardIdle()

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

        return true
    }

    // MARK: - Image Paste

    /// 캡처된 스크린샷들을 대상 앱에 이미지로 순서대로 붙여넣기
    /// 흐름: 영어 입력소스 전환 → 각 이미지(클립보드 복사 → Ctrl+V → Cmd+V) → 입력소스 복원
    @MainActor
    /// - Parameter clipboardTextAfter: 끝난 뒤 클립보드에 남길 텍스트 (보통 방금 붙여넣은 받아쓰기 결과).
    func insertImages(_ images: [Data], targetApp: NSRunningApplication? = nil, clipboardTextAfter: String? = nil) async {
        guard !images.isEmpty else { return }

        // 대상 앱이 이미 활성화되어 있어야 함
        if let target = targetApp,
           target.bundleIdentifier != Bundle.main.bundleIdentifier
        {
            let isFront = NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier
            if !isFront {
                _ = await activateApp(target)
            }
        }

        // 영어 입력소스로 전환 (한글 모드에서 Ctrl+V 미작동 방지)
        let originalSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        switchToASCIIInputSource()

        let pasteboard = NSPasteboard.general

        // 취소를 포함한 모든 종료 경로에서 입력소스 복원 + 클립보드 정리를 보장
        // (originalSource 캡처 이후에만 설치 — 위 이른 return에는 적용되지 않음)
        defer {
            if let original = originalSource {
                TISSelectInputSource(original)
            }
            pasteboard.clearContents()
            if let clipboardTextAfter {
                pasteboard.setString(clipboardTextAfter, forType: .string)
            }
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        for imageData in images {
            guard !Task.isCancelled else { break }

            guard let bitmapRep = NSBitmapImageRep(data: imageData),
                  let pngData = bitmapRep.representation(using: .png, properties: [:])
            else { continue }

            pasteboard.clearContents()
            pasteboard.setData(pngData, forType: .png)

            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2초 — 클립보드 안정화
            await waitForKeyboardIdle()

            // Ctrl+V (터미널 Claude CLI)
            sendPasteKey(flags: .maskControl)
            try? await Task.sleep(nanoseconds: 200_000_000)

            // Cmd+V (브라우저)
            sendPasteKey(flags: .maskCommand)
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6초 — 웹 업로드 대기
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
        Task { @MainActor in
            PermissionManager.shared.requestAccessibility()
        }
    }
}
