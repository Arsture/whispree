import AppKit
import Foundation
import KeyboardShortcuts

/// 사용자 지정 단축키. 일반 combo(mod+key)와 modifier-only(Right Option 등)를 모두 표현.
///
/// `modifierOnly`의 `keyCode`는 CGEvent keycode (좌우 구분):
/// - 55 = Left Command, 54 = Right Command
/// - 58 = Left Option,  61 = Right Option
/// - 59 = Left Control, 62 = Right Control
/// - 56 = Left Shift,   60 = Right Shift
/// - 63 = Fn
enum WhispreeShortcut: Codable, Equatable, Hashable {
    case combo(keyCode: Int, modifiersRaw: UInt)
    case modifierOnly(keyCode: Int)

    // MARK: - Bridging to KeyboardShortcuts.Shortcut

    init(combo shortcut: KeyboardShortcuts.Shortcut) {
        self = .combo(
            keyCode: shortcut.key?.rawValue ?? -1,
            modifiersRaw: shortcut.modifiers.rawValue
        )
    }

    var comboShortcut: KeyboardShortcuts.Shortcut? {
        guard case let .combo(keyCode, modifiersRaw) = self else { return nil }
        let key = KeyboardShortcuts.Key(rawValue: keyCode)
        return KeyboardShortcuts.Shortcut(key, modifiers: NSEvent.ModifierFlags(rawValue: modifiersRaw))
    }

    // MARK: - Display

    var displayLabel: String {
        switch self {
            case let .combo(keyCode, modifiersRaw):
                let mods = NSEvent.ModifierFlags(rawValue: modifiersRaw)
                let key = KeyboardShortcuts.Key(rawValue: keyCode)
                let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: mods)
                return "\(shortcut)"
            case let .modifierOnly(keyCode):
                return Self.modifierOnlyLabel(for: keyCode)
        }
    }

    /// "L⌥", "R⌥", "Fn" 등 단일 modifier 라벨. side letter를 glyph 앞에 둬서 combo(`⌥R`)와 구분.
    static func modifierOnlyLabel(for keyCode: Int) -> String {
        switch keyCode {
            case 55: "L⌘"
            case 54: "R⌘"
            case 58: "L⌥"
            case 61: "R⌥"
            case 59: "L⌃"
            case 62: "R⌃"
            case 56: "L⇧"
            case 60: "R⇧"
            case 63: "Fn"
            default: "?"
        }
    }

    // MARK: - Defaults

    /// Ctrl+Shift+R (KeyboardShortcuts.Key.r.rawValue = 15)
    static let defaultToggleRecording: WhispreeShortcut = .combo(
        keyCode: 15,
        modifiersRaw: NSEvent.ModifierFlags([.control, .shift]).rawValue
    )

    /// Ctrl+Shift+D (KeyboardShortcuts.Key.d.rawValue = 2)
    static let defaultQuickFix: WhispreeShortcut = .combo(
        keyCode: 2,
        modifiersRaw: NSEvent.ModifierFlags([.control, .shift]).rawValue
    )

    /// 이 keyCode가 좌/우 구분이 있는 modifier인지 확인 (녹화 모드에서 판정용).
    static func isRecognizedModifierKeyCode(_ keyCode: Int) -> Bool {
        switch keyCode {
            case 54, 55, 56, 58, 59, 60, 61, 62, 63: true
            default: false
        }
    }

    /// modifier-only 바인딩의 keyDown 매칭용: 어떤 flags 비트가 눌린 상태인지.
    /// (PTT 종료 판정에 사용 — flag가 0으로 떨어지면 release.)
    static func modifierFlagMask(for keyCode: Int) -> NSEvent.ModifierFlags {
        switch keyCode {
            case 54, 55: .command
            case 58, 61: .option
            case 59, 62: .control
            case 56, 60: .shift
            case 63: []  // Fn은 ModifierFlags.function이지만 CGEvent flag와 별도 처리
            default: []
        }
    }
}
