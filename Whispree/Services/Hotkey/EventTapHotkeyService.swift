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

            // Escape cancels recording
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
