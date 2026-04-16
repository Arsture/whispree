import AppKit
import Foundation
import KeyboardShortcuts

/// CGEventTap-based hotkey service that intercepts key events at HID level,
/// BEFORE macOS system shortcuts (Spotlight, input source switching, etc.).
/// This allows capturing and overriding Option+Space, Cmd+Space, etc.
final class EventTapHotkeyService {
    static let shared = EventTapHotkeyService()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Hotkey Bindings

    struct Binding {
        let keyCode: Int
        let modifiers: NSEvent.ModifierFlags
        let onKeyDown: () -> Void
        let onKeyUp: (() -> Void)?
    }

    private var bindings: [Binding] = []

    // MARK: - Recording Mode

    private(set) var isRecording = false
    private var onRecorded: ((KeyboardShortcuts.Shortcut) -> Void)?
    private var onRecordingCancel: (() -> Void)?
    private var onModifiersChanged: ((NSEvent.ModifierFlags) -> Void)?

    /// 통합 ESC 핸들러 — 우선순위: 미리보기 → 선택 패널 → 파이프라인 취소
    var onEscPressed: (() -> Void)?
    /// 상태 플래그 — CGEventTap 콜백에서 동기적으로 읽음
    var isPreviewOpen: Bool = false
    var isSelectionActive: Bool = false
    var isPipelineActive: Bool = false

    // MARK: - Option Long-Press (recording-only)

    /// 녹음 중 Option 단독 long-press 감지 활성 여부. HotkeyManager가 `isRecording` 변화에 맞춰 토글.
    var isOptionLongPressEnabled: Bool = false
    /// Option 단독 long-press 감지 시 호출 (main queue).
    var onOptionLongPress: (() -> Void)?
    /// long-press 지속 시간 (초).
    private let optionLongPressDuration: TimeInterval = 0.5
    /// Option down 타임스탬프 — long-press 판정용.
    private var optionDownAt: Date?
    /// 스케줄된 long-press trigger work item — Option 떼거나 다른 키 누르면 취소.
    private var optionLongPressWorkItem: DispatchWorkItem?

    private let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    private init() {}

    // MARK: - Lifecycle

    var isRunning: Bool {
        eventTap != nil
    }

    func start() {
        guard eventTap == nil else { return }
        guard AXIsProcessTrusted() else {
            print("[EventTap] Accessibility permission required")
            return
        }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: Self.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[EventTap] Failed to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Binding Management

    func register(
        keyCode: Int,
        modifiers: NSEvent.ModifierFlags,
        keyDown: @escaping () -> Void,
        keyUp: (() -> Void)? = nil
    ) {
        bindings.append(Binding(
            keyCode: keyCode,
            modifiers: modifiers.intersection(relevantModifiers),
            onKeyDown: keyDown,
            onKeyUp: keyUp
        ))
    }

    /// Register from a KeyboardShortcuts.Shortcut
    func register(
        shortcut: KeyboardShortcuts.Shortcut,
        keyDown: @escaping () -> Void,
        keyUp: (() -> Void)? = nil
    ) {
        register(
            keyCode: shortcut.key?.rawValue ?? -1,
            modifiers: shortcut.modifiers,
            keyDown: keyDown,
            keyUp: keyUp
        )
    }

    func clearBindings() {
        bindings.removeAll()
    }

    // MARK: - Recording

    func startRecording(
        onCapture: @escaping (KeyboardShortcuts.Shortcut) -> Void,
        onCancel: @escaping () -> Void,
        onModifiers: ((NSEvent.ModifierFlags) -> Void)? = nil
    ) {
        isRecording = true
        onRecorded = onCapture
        onRecordingCancel = onCancel
        onModifiersChanged = onModifiers
    }

    func stopRecording() {
        isRecording = false
        onRecorded = nil
        onRecordingCancel = nil
        onModifiersChanged = nil
    }

    // MARK: - CGEvent Callback

    // MARK: - Option Long-Press Tracking

    /// Option 단독 long-press 감지. flagsChanged로 Option 상태 추적,
    /// keyDown/keyUp 시 다른 키 입력이 있으면 modifier 사용으로 간주해 취소.
    private func handleOptionLongPressTracking(
        type: CGEventType,
        keyCode: Int,
        mods: NSEvent.ModifierFlags
    ) {
        // 다른 키 입력 — Option이 modifier로 사용된 것이므로 long-press 취소
        if type == .keyDown || type == .keyUp {
            if optionDownAt != nil {
                cancelOptionLongPress()
            }
            return
        }

        guard type == .flagsChanged else { return }

        let isOptionAlone = (mods == .option)

        if isOptionAlone, optionDownAt == nil {
            // Option 단독 누름 시작 — long-press 타이머 예약
            optionDownAt = Date()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                // 트리거 시점에 여전히 Option만 눌려있고 이 work item이 유효한지 확인
                guard self.optionDownAt != nil else { return }
                self.onOptionLongPress?()
                // 한 번 트리거된 후엔 Option 뗄 때까지 재트리거 방지
                self.optionDownAt = nil
                self.optionLongPressWorkItem = nil
            }
            optionLongPressWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + optionLongPressDuration,
                execute: work
            )
        } else if !isOptionAlone {
            // Option을 떼거나 다른 modifier가 추가됨 — 취소
            cancelOptionLongPress()
        }
    }

    private func cancelOptionLongPress() {
        optionLongPressWorkItem?.cancel()
        optionLongPressWorkItem = nil
        optionDownAt = nil
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let service = Unmanaged<EventTapHotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
        return service.handleEvent(type: type, event: event)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if system disabled it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let eventMods = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
            .intersection(relevantModifiers)

        // -- Option long-press (녹음 중 단독 Option 0.5s hold) --
        // isRecording은 단축키 녹화 모드 플래그 — 단축키 녹화 중엔 long-press 감지 비활성.
        if isOptionLongPressEnabled, !isRecording {
            handleOptionLongPressTracking(type: type, keyCode: keyCode, mods: eventMods)
        }

        // -- Recording mode --
        if isRecording {
            if type == .flagsChanged {
                DispatchQueue.main.async { [weak self] in
                    self?.onModifiersChanged?(eventMods)
                }
                return Unmanaged.passUnretained(event) // Don't consume modifier-only events
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            // Escape cancels shortcut recording
            if keyCode == 53 {
                DispatchQueue.main.async { [weak self] in
                    self?.onRecordingCancel?()
                    self?.stopRecording()
                }
                return nil
            }

            // Require at least one modifier
            guard !eventMods.isEmpty else {
                return Unmanaged.passUnretained(event)
            }

            let key = KeyboardShortcuts.Key(rawValue: keyCode)
            let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: eventMods)

            DispatchQueue.main.async { [weak self] in
                self?.onRecorded?(shortcut)
                self?.stopRecording()
            }
            return nil // Consume — prevents Spotlight, input source, etc.
        }

        // -- Normal mode: match hotkeys --
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        // ESC — 컨텍스트별 분기 (미리보기 → 선택 → 파이프라인 취소)
        if type == .keyDown, keyCode == 53,
           isPreviewOpen || isSelectionActive || isPipelineActive
        {
            DispatchQueue.main.async { [weak self] in
                self?.onEscPressed?()
            }
            return nil // 이벤트 소비
        }

        for binding in bindings {
            if keyCode == binding.keyCode, eventMods == binding.modifiers {
                if type == .keyDown {
                    DispatchQueue.main.async { binding.onKeyDown() }
                } else if type == .keyUp {
                    DispatchQueue.main.async { binding.onKeyUp?() }
                }
                return nil // Consume matched hotkey
            }
        }

        return Unmanaged.passUnretained(event) // Pass through unmatched
    }
}
