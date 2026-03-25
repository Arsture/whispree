import Foundation
import AppKit
import KeyboardShortcuts
import Combine

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.r, modifiers: [.control, .shift]))
    static let quickFix = Self("quickFix", default: .init(.d, modifiers: [.control, .shift]))
}

@MainActor
final class HotkeyManager: ObservableObject {
    var onRecordingToggle: ((Bool) -> Void)?
    var onCancel: (() -> Void)?
    var onQuickFix: (() -> Void)?

    private let appState: AppState
    private let eventTap = EventTapHotkeyService.shared
    private var isKeyDown = false
    private var escMonitorLocal: Any?
    private var escMonitorGlobal: Any?

    init(appState: AppState) {
        self.appState = appState
        eventTap.start()
        setupHotkeys()
        setupEscCancel()
    }

    private func setupHotkeys() {
        eventTap.clearBindings()

        switch appState.settings.recordingMode {
        case .pushToTalk:
            setupPushToTalk()
        case .toggle:
            setupToggleMode()
        }
        setupQuickFixHotkey()
    }

    func updateMode(_ mode: RecordingMode) {
        appState.settings.recordingMode = mode
        appState.settings.save()
        setupHotkeys()
    }

    /// Re-register hotkeys after shortcut changes (called by ShortcutRecorderButton)
    func reloadHotkeys() {
        setupHotkeys()
    }

    private func setupPushToTalk() {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) else { return }
        eventTap.register(shortcut: shortcut,
            keyDown: { [weak self] in
                guard let self, !self.isKeyDown else { return }
                self.isKeyDown = true
                self.onRecordingToggle?(true)
            },
            keyUp: { [weak self] in
                guard let self, self.isKeyDown else { return }
                self.isKeyDown = false
                self.onRecordingToggle?(false)
            }
        )
    }

    private func setupToggleMode() {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) else { return }
        eventTap.register(shortcut: shortcut,
            keyDown: { [weak self] in
                guard let self else { return }
                let shouldRecord = self.appState.transcriptionState == .idle
                self.onRecordingToggle?(shouldRecord)
            }
        )
    }

    private func setupQuickFixHotkey() {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .quickFix) else { return }
        eventTap.register(shortcut: shortcut,
            keyDown: { [weak self] in
                self?.onQuickFix?()
            }
        )
    }

    // MARK: - ESC to Cancel

    private func setupEscCancel() {
        escMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.handleEsc()
                return nil
            }
            return event
        }

        escMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.handleEsc()
            }
        }
    }

    private func handleEsc() {
        guard appState.transcriptionState != .idle else { return }
        onCancel?()
    }

    deinit {
        if let monitor = escMonitorLocal { NSEvent.removeMonitor(monitor) }
        if let monitor = escMonitorGlobal { NSEvent.removeMonitor(monitor) }
    }
}
