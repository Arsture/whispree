import AppKit
import ApplicationServices

@MainActor
final class QuickFixService {
    /// Captures the currently selected text from the frontmost app by simulating Cmd+C.
    /// Returns the selected text, or nil if nothing was selected.
    func captureSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Clear clipboard to detect new content
        pasteboard.clearContents()

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .combinedSessionState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        else {
            // Restore clipboard on failure
            if let prev = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(prev, forType: .string)
            }
            return nil
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)

        // Wait for clipboard to update
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms

        let selectedText = pasteboard.string(forType: .string)

        // Restore previous clipboard
        pasteboard.clearContents()
        if let prev = previousContents {
            pasteboard.setString(prev, forType: .string)
        }

        guard let text = selectedText, !text.isEmpty else { return nil }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Replaces the currently selected text in the target app with the new text.
    func replaceText(with newText: String, in targetApp: NSRunningApplication) async -> Bool {
        targetApp.activate()

        // Wait for app to become frontmost
        let deadline = Date().addingTimeInterval(0.5)
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != targetApp.processIdentifier,
              Date() < deadline
        {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Set clipboard to new text
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)

        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Simulate Cmd+V to paste (replaces selection)
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

        // Restore clipboard after delay
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s
            pasteboard.clearContents()
            if let prev = previousContents {
                pasteboard.setString(prev, forType: .string)
            }
        }

        return true
    }

    // MARK: - Dictionary Storage

    /// Adds a corrected word to the "Quick Fix" domain word set (STT + LLM).
    /// Creates the set if it doesn't exist.
    func addWordToDictionary(_ word: String, appState: AppState) {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let index = ensureQuickFixSet(appState: appState)
        if !appState.settings.domainWordSets[index].words.contains(trimmed) {
            appState.settings.domainWordSets[index].words.append(trimmed)
        }
        appState.settings.save()
    }

    /// Adds a correction mapping to the "Quick Fix" domain word set (LLM only).
    /// Creates the set if it doesn't exist.
    func addCorrectionToDictionary(from: String, to: String, appState: AppState) {
        let trimmedFrom = from.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTo = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFrom.isEmpty, !trimmedTo.isEmpty else { return }

        let index = ensureQuickFixSet(appState: appState)
        // Avoid duplicate mappings
        let alreadyExists = appState.settings.domainWordSets[index].corrections.contains {
            $0.from == trimmedFrom && $0.to == trimmedTo
        }
        if !alreadyExists {
            let mapping = CorrectionMapping(from: trimmedFrom, to: trimmedTo)
            appState.settings.domainWordSets[index].corrections.append(mapping)
        }
        appState.settings.save()
    }

    /// Returns the index of the "Quick Fix" word set, creating it if needed.
    private func ensureQuickFixSet(appState: AppState) -> Int {
        if let index = appState.settings.domainWordSets.firstIndex(where: { $0.name == "Quick Fix" }) {
            return index
        }
        let quickFixSet = DomainWordSet(name: "Quick Fix", words: [])
        appState.settings.domainWordSets.append(quickFixSet)
        return appState.settings.domainWordSets.count - 1
    }
}
