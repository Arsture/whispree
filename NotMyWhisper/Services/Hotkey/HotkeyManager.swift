import Foundation
import AppKit
import KeyboardShortcuts
import Combine

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.r, modifiers: [.control, .shift]))
}

@MainActor
final class HotkeyManager: ObservableObject {
    var onRecordingToggle: ((Bool) -> Void)?
    var onCancel: (() -> Void)?

    private let appState: AppState
    private var isKeyDown = false
    private var escMonitorLocal: Any?
    private var escMonitorGlobal: Any?

    init(appState: AppState) {
        self.appState = appState
        setupHotkeys()
        setupEscCancel()
    }

    private func setupHotkeys() {
        switch appState.settings.recordingMode {
        case .pushToTalk:
            setupPushToTalk()
        case .toggle:
            setupToggleMode()
        }
    }

    func updateMode(_ mode: RecordingMode) {
        KeyboardShortcuts.removeAllHandlers()

        appState.settings.recordingMode = mode
        appState.settings.save()

        switch mode {
        case .pushToTalk:
            setupPushToTalk()
        case .toggle:
            setupToggleMode()
        }
    }

    private func setupPushToTalk() {
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            guard let self, !self.isKeyDown else { return }
            self.isKeyDown = true
            self.onRecordingToggle?(true)
        }

        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            guard let self, self.isKeyDown else { return }
            self.isKeyDown = false
            self.onRecordingToggle?(false)
        }
    }

    private func setupToggleMode() {
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            guard let self else { return }
            let shouldRecord = self.appState.transcriptionState == .idle
            self.onRecordingToggle?(shouldRecord)
        }
    }

    // MARK: - ESC to Cancel

    private func setupEscCancel() {
        // Local monitor (when app is focused)
        escMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.handleEsc()
                return nil // consume the event
            }
            return event
        }

        // Global monitor (when app is not focused)
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
        if let monitor = escMonitorLocal {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = escMonitorGlobal {
            NSEvent.removeMonitor(monitor)
        }
    }
}
