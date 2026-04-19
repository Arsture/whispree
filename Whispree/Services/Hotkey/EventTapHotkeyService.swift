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

    enum BindingKind {
        case combo(keyCode: Int, modifiers: NSEvent.ModifierFlags)
        case modifierOnly(keyCode: Int)
    }

    final class Binding {
        let kind: BindingKind
        let onKeyDown: () -> Void
        let onKeyUp: (() -> Void)?
        var isModifierHeld: Bool = false

        init(kind: BindingKind, onKeyDown: @escaping () -> Void, onKeyUp: (() -> Void)?) {
            self.kind = kind
            self.onKeyDown = onKeyDown
            self.onKeyUp = onKeyUp
        }
    }

    private var bindings: [Binding] = []

    // MARK: - Recording Mode

    private(set) var isRecording = false
    private var onRecorded: ((WhispreeShortcut) -> Void)?
    private var onRecordingCancel: (() -> Void)?
    private var onModifiersChanged: ((NSEvent.ModifierFlags) -> Void)?

    /// 녹화 중 단일 modifier press tracking — release 시 intervening keyDown이 없으면 modifier-only 커밋.
    private var recordingModifierCandidate: (keyCode: Int, armed: Bool)?

    /// 통합 ESC 핸들러 — 우선순위: 미리보기 → 선택 패널 → 파이프라인 취소
    var onEscPressed: (() -> Void)?
    /// 상태 플래그 — CGEventTap 콜백에서 동기적으로 읽음
    var isPreviewOpen: Bool = false
    var isSelectionActive: Bool = false
    var isPipelineActive: Bool = false

    // MARK: - Left Option Long-Press (recording-only)

    /// 녹음 중 Left Option 단독 long-press 감지 활성 여부. HotkeyManager가 `isRecording` 변화에 맞춰 토글.
    /// R-Option은 PTT 바인딩 후보라 L-Option만 토글로 사용.
    var isOptionLongPressEnabled: Bool = false
    /// Left Option 단독 long-press 감지 시 호출 (main queue).
    var onOptionLongPress: (() -> Void)?
    /// long-press 지속 시간 (초).
    private let optionLongPressDuration: TimeInterval = 0.5
    /// L-Option down 타임스탬프 — long-press 판정용.
    private var optionDownAt: Date?
    /// 스케줄된 long-press trigger work item — L-Option 떼거나 다른 키 누르면 취소.
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
            Task { @MainActor in PermissionManager.shared.requestAccessibility() }
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

    /// Register a WhispreeShortcut (combo or modifier-only).
    func register(
        whispreeShortcut: WhispreeShortcut,
        keyDown: @escaping () -> Void,
        keyUp: (() -> Void)? = nil
    ) {
        let kind: BindingKind
        switch whispreeShortcut {
            case let .combo(keyCode, modifiersRaw):
                let mods = NSEvent.ModifierFlags(rawValue: modifiersRaw).intersection(relevantModifiers)
                kind = .combo(keyCode: keyCode, modifiers: mods)
            case let .modifierOnly(keyCode):
                kind = .modifierOnly(keyCode: keyCode)
        }
        bindings.append(Binding(kind: kind, onKeyDown: keyDown, onKeyUp: keyUp))
    }

    func clearBindings() {
        bindings.removeAll()
    }

    // MARK: - Recording

    func startRecording(
        onCapture: @escaping (WhispreeShortcut) -> Void,
        onCancel: @escaping () -> Void,
        onModifiers: ((NSEvent.ModifierFlags) -> Void)? = nil
    ) {
        isRecording = true
        onRecorded = onCapture
        onRecordingCancel = onCancel
        onModifiersChanged = onModifiers
        recordingModifierCandidate = nil
    }

    func stopRecording() {
        isRecording = false
        onRecorded = nil
        onRecordingCancel = nil
        onModifiersChanged = nil
        recordingModifierCandidate = nil
    }

    // MARK: - Device-specific flag bits (L/R distinction)

    /// CGEventFlags의 NX_DEVICE* 비트로 좌/우 구분 modifier 상태 확인.
    private static func isDeviceSpecificBitSet(keyCode: Int, flagsRaw: UInt64) -> Bool {
        switch keyCode {
            case 58: (flagsRaw & 0x20) != 0          // NX_DEVICELALTKEYMASK
            case 61: (flagsRaw & 0x40) != 0          // NX_DEVICERALTKEYMASK
            case 59: (flagsRaw & 0x01) != 0          // NX_DEVICELCTLKEYMASK
            case 62: (flagsRaw & 0x2000) != 0        // NX_DEVICERCTLKEYMASK
            case 55: (flagsRaw & 0x08) != 0          // NX_DEVICELCMDKEYMASK
            case 54: (flagsRaw & 0x10) != 0          // NX_DEVICERCMDKEYMASK
            case 56: (flagsRaw & 0x02) != 0          // NX_DEVICELSHIFTKEYMASK
            case 60: (flagsRaw & 0x04) != 0          // NX_DEVICERSHIFTKEYMASK
            case 63: (flagsRaw & 0x00800000) != 0    // kCGEventFlagMaskSecondaryFn
            default: false
        }
    }

    /// 오직 target modifier만 눌려있는 상태인지 (다른 modifier와의 combo 아닌지).
    private func isOnlyTargetModifierActive(keyCode: Int, flagsRaw: UInt64) -> Bool {
        let eventMods = NSEvent.ModifierFlags(rawValue: UInt(flagsRaw)).intersection(relevantModifiers)
        if keyCode == 63 {
            // Fn은 relevantModifiers에 없음 — 다른 modifier가 비어야 하고 Fn 비트가 설정돼야 함
            return eventMods.isEmpty && (flagsRaw & 0x00800000) != 0
        }
        return eventMods == WhispreeShortcut.modifierFlagMask(for: keyCode)
    }

    // MARK: - Left Option Long-Press Tracking

    /// Left Option 단독 long-press 감지. flagsChanged로 L-Option 상태 추적.
    /// device-specific bit(NX_DEVICELALTKEYMASK=0x20)로 좌측만 판정 — R-Option은 PTT 바인딩 후보라 제외.
    /// L-Option이 modifier-only PTT로 묶여있으면 skip (중복 방지).
    private func handleOptionLongPressTracking(
        type: CGEventType,
        keyCode: Int,
        flagsRaw: UInt64,
        mods: NSEvent.ModifierFlags
    ) {
        // L-Option이 PTT에 바인딩돼 있으면 토글 비활성 (key가 겹침)
        let leftOptionBoundAsPTT = bindings.contains { binding in
            if case let .modifierOnly(kc) = binding.kind, kc == 58 { return true }
            return false
        }
        if leftOptionBoundAsPTT { return }

        // 다른 키 입력 — L-Option이 modifier로 사용된 것이므로 long-press 취소
        if type == .keyDown || type == .keyUp {
            if optionDownAt != nil {
                cancelOptionLongPress()
            }
            return
        }

        guard type == .flagsChanged else { return }

        // L-Option 단독 — 좌측 device bit만 set, 우측/타 modifier 없음
        let leftOptionBit = (flagsRaw & 0x20) != 0
        let rightOptionBit = (flagsRaw & 0x40) != 0
        let isLeftOptionAlone = leftOptionBit && !rightOptionBit && mods == .option

        if isLeftOptionAlone, optionDownAt == nil {
            // L-Option 단독 누름 시작 — long-press 타이머 예약
            optionDownAt = Date()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard self.optionDownAt != nil else { return }
                self.onOptionLongPress?()
                self.optionDownAt = nil
                self.optionLongPressWorkItem = nil
            }
            optionLongPressWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + optionLongPressDuration,
                execute: work
            )
        } else if !isLeftOptionAlone {
            // L-Option을 떼거나 다른 modifier가 추가됨 — 취소
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
        let flagsRaw = event.flags.rawValue
        let eventMods = NSEvent.ModifierFlags(rawValue: UInt(flagsRaw))
            .intersection(relevantModifiers)

        // -- L-Option long-press (녹음 중 좌측 Option 0.5s hold) --
        // isRecording은 단축키 녹화 모드 플래그 — 단축키 녹화 중엔 long-press 감지 비활성.
        if isOptionLongPressEnabled, !isRecording {
            handleOptionLongPressTracking(type: type, keyCode: keyCode, flagsRaw: flagsRaw, mods: eventMods)
        }

        // -- Recording mode --
        if isRecording {
            return handleRecordingEvent(type: type, event: event, keyCode: keyCode, flagsRaw: flagsRaw, eventMods: eventMods)
        }

        // -- Normal mode: match hotkeys --

        // ESC — 컨텍스트별 분기 (미리보기 → 선택 → 파이프라인 취소)
        if type == .keyDown, keyCode == 53,
           isPreviewOpen || isSelectionActive || isPipelineActive
        {
            DispatchQueue.main.async { [weak self] in
                self?.onEscPressed?()
            }
            return nil // 이벤트 소비
        }

        // Modifier-only bindings: flagsChanged에서 press/release 감지
        if type == .flagsChanged {
            dispatchModifierOnlyBindings(keyCode: keyCode, flagsRaw: flagsRaw)
            return Unmanaged.passUnretained(event)
        }

        // Combo bindings: keyDown/keyUp 매칭
        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        for binding in bindings {
            guard case let .combo(bKeyCode, bMods) = binding.kind else { continue }
            if keyCode == bKeyCode, eventMods == bMods {
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

    // MARK: - Modifier-only dispatch

    /// flagsChanged 시 등록된 modifier-only bindings에 대해 press/release 판정 및 콜백 호출.
    private func dispatchModifierOnlyBindings(keyCode: Int, flagsRaw: UInt64) {
        for binding in bindings {
            guard case let .modifierOnly(bKeyCode) = binding.kind else { continue }
            let sideBitSet = Self.isDeviceSpecificBitSet(keyCode: bKeyCode, flagsRaw: flagsRaw)

            if binding.isModifierHeld {
                // 릴리즈 감지 — device-specific bit이 꺼지면 keyUp
                if !sideBitSet {
                    binding.isModifierHeld = false
                    DispatchQueue.main.async { binding.onKeyUp?() }
                }
            } else {
                // 새로 눌림 — 이 이벤트가 대상 keyCode이고 사이드 비트가 set이고 타겟만 활성일 때
                if sideBitSet,
                   keyCode == bKeyCode,
                   isOnlyTargetModifierActive(keyCode: bKeyCode, flagsRaw: flagsRaw)
                {
                    binding.isModifierHeld = true
                    DispatchQueue.main.async { binding.onKeyDown() }
                }
            }
        }
    }

    // MARK: - Recording event handling

    private func handleRecordingEvent(
        type: CGEventType,
        event: CGEvent,
        keyCode: Int,
        flagsRaw: UInt64,
        eventMods: NSEvent.ModifierFlags
    ) -> Unmanaged<CGEvent>? {
        switch type {
            case .flagsChanged:
                DispatchQueue.main.async { [weak self] in
                    self?.onModifiersChanged?(eventMods)
                }
                handleRecordingFlagsChanged(keyCode: keyCode, flagsRaw: flagsRaw)
                return Unmanaged.passUnretained(event) // modifier-only 이벤트는 통과

            case .keyDown:
                // Escape cancels shortcut recording
                if keyCode == 53 {
                    DispatchQueue.main.async { [weak self] in
                        self?.onRecordingCancel?()
                        self?.stopRecording()
                    }
                    return nil
                }

                // 일반 키 입력 → modifier-only 후보 무효화 (combo 의도)
                recordingModifierCandidate = nil

                // 녹화 commit은 반드시 modifier가 하나 이상 있어야 함
                guard !eventMods.isEmpty else {
                    return Unmanaged.passUnretained(event)
                }

                let key = KeyboardShortcuts.Key(rawValue: keyCode)
                let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: eventMods)
                let whispreeShortcut = WhispreeShortcut(combo: shortcut)

                DispatchQueue.main.async { [weak self] in
                    self?.onRecorded?(whispreeShortcut)
                    self?.stopRecording()
                }
                return nil // Consume

            default:
                return Unmanaged.passUnretained(event)
        }
    }

    /// 녹화 모드 flagsChanged — modifier 단독 press/release 추적.
    private func handleRecordingFlagsChanged(keyCode: Int, flagsRaw: UInt64) {
        guard WhispreeShortcut.isRecognizedModifierKeyCode(keyCode) else { return }

        let sideBitSet = Self.isDeviceSpecificBitSet(keyCode: keyCode, flagsRaw: flagsRaw)

        if sideBitSet {
            // 이 modifier가 눌림
            if recordingModifierCandidate == nil,
               isOnlyTargetModifierActive(keyCode: keyCode, flagsRaw: flagsRaw)
            {
                // 첫 modifier이고 단독 상태 → 후보로 arm
                recordingModifierCandidate = (keyCode, armed: true)
            } else {
                // 다른 modifier가 이미 눌려있거나 추가됨 → disarm (combo 의도)
                recordingModifierCandidate?.armed = false
            }
        } else {
            // 이 modifier 릴리즈
            if let candidate = recordingModifierCandidate,
               candidate.keyCode == keyCode,
               candidate.armed,
               // 릴리즈 시점에 다른 modifier도 없어야 함 (깔끔한 단독 release)
               NSEvent.ModifierFlags(rawValue: UInt(flagsRaw)).intersection(relevantModifiers).isEmpty,
               (flagsRaw & 0x00800000) == 0  // Fn도 꺼짐
            {
                let shortcut = WhispreeShortcut.modifierOnly(keyCode: keyCode)
                DispatchQueue.main.async { [weak self] in
                    self?.onRecorded?(shortcut)
                    self?.stopRecording()
                }
            }
            recordingModifierCandidate = nil
        }
    }
}
