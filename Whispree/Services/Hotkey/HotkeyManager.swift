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
    /// 녹음 중 Option 단독 long-press 시 호출 — 스크린샷 전달 토글.
    var onOptionLongPress: (() -> Void)?

    private let appState: AppState
    let eventTapService = EventTapHotkeyService.shared
    private var eventTap: EventTapHotkeyService { eventTapService }
    private var isKeyDown = false
    private var escMonitorLocal: Any?

    init(appState: AppState) {
        self.appState = appState
        eventTap.start()
        setupHotkeys()
        setupEscCancel()
        setupOptionLongPress()
    }

    private func setupOptionLongPress() {
        eventTap.onOptionLongPress = { [weak self] in
            self?.onOptionLongPress?()
        }
        // 녹음 중일 때만 long-press 감지 활성
        appState.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.eventTap.isOptionLongPressEnabled = isRecording
            }
            .store(in: &stateCancellable)
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
        // 로컬 모니터 — Whispree가 포커스일 때 ESC 소비 (선택 패널 등)
        escMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, let self else { return event }
            if self.appState.transcriptionState != .idle {
                // EventTap의 onEscPressed와 같은 통합 핸들러 호출
                self.handleUnifiedEsc()
                return nil
            }
            return event
        }

        // CGEventTap — 통합 ESC 핸들러 (우선순위: 미리보기 → 선택 → 취소)
        eventTap.onEscPressed = { [weak self] in
            self?.handleUnifiedEsc()
        }

        // 파이프라인 상태 동기화
        appState.$transcriptionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.eventTap.isPipelineActive = (state != .idle)
                self.eventTap.isSelectionActive = (state == .selectingScreenshots)
            }
            .store(in: &stateCancellable)
    }

    /// 통합 ESC 핸들러 — 우선순위대로 분기
    private func handleUnifiedEsc() {
        // 1. 미리보기 열려있으면 → 미리보기만 닫기
        if eventTap.isPreviewOpen {
            onEscPreview?()
            return
        }
        // 2. 선택 패널 활성이면 → 건너뛰기
        if appState.transcriptionState == .selectingScreenshots {
            appState.screenshotSelectionCallback?([])
            return
        }
        // 3. 녹음/전사/교정 중이면 → 파이프라인 취소
        if appState.transcriptionState != .idle {
            onCancel?()
        }
    }

    /// 미리보기 닫기 콜백 — AppDelegate에서 설정
    var onEscPreview: (() -> Void)?

    private var stateCancellable = Set<AnyCancellable>()

    deinit {
        if let monitor = escMonitorLocal { NSEvent.removeMonitor(monitor) }
    }
}
