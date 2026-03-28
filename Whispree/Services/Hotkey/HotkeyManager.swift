import AppKit
import Combine
import Foundation
import KeyboardShortcuts

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
        eventTap.register(
            shortcut: shortcut,
            keyDown: { [weak self] in
                guard let self, !self.isKeyDown else { return }
                isKeyDown = true
                onRecordingToggle?(true)
            },
            keyUp: { [weak self] in
                guard let self, isKeyDown else { return }
                isKeyDown = false
                onRecordingToggle?(false)
            }
        )
    }

    private func setupToggleMode() {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) else { return }
        eventTap.register(
            shortcut: shortcut,
            keyDown: { [weak self] in
                guard let self else { return }
                let shouldRecord = appState.transcriptionState == .idle
                onRecordingToggle?(shouldRecord)
            }
        )
    }

    private func setupQuickFixHotkey() {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .quickFix) else { return }
        eventTap.register(
            shortcut: shortcut,
            keyDown: { [weak self] in
                self?.onQuickFix?()
            }
        )
    }

    // MARK: - ESC to Cancel

    private func setupEscCancel() {
        // 로컬 모니터 — Whispree가 포커스일 때 ESC 소비
        escMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53, self?.appState.transcriptionState != .idle {
                self?.onCancel?()
                return nil
            }
            return event
        }

        // CGEventTap — 다른 앱이 포커스일 때도 ESC 소비
        eventTap.onEscPressed = { [weak self] in
            self?.onCancel?()
        }

        // 파이프라인 상태 동기화 — EventTap이 메인 스레드 외에서도 읽을 수 있도록
        appState.$transcriptionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.eventTap.isPipelineActive = (state != .idle)
            }
            .store(in: &stateCancellable)
    }

    private var stateCancellable = Set<AnyCancellable>()

    deinit {
        if let monitor = escMonitorLocal { NSEvent.removeMonitor(monitor) }
    }
}
