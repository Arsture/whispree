import AppKit
import Foundation
import KeyboardShortcuts

struct ShortcutConflict: Equatable {
    let featureName: String
    let source: String
}

enum ShortcutConflictDetector {
    private struct KnownShortcut {
        let key: KeyboardShortcuts.Key
        let modifiers: NSEvent.ModifierFlags
        let featureName: String
        let source: String
    }

    // MARK: - Known macOS System Shortcuts

    private static let knownShortcuts: [KnownShortcut] = [
        // Spotlight
        .init(key: .space, modifiers: [.command], featureName: "Spotlight 검색", source: "macOS"),
        .init(key: .space, modifiers: [.option], featureName: "Spotlight (대체 설정)", source: "macOS"),

        // Input Source
        .init(key: .space, modifiers: [.control], featureName: "입력 소스 전환", source: "macOS"),
        .init(key: .space, modifiers: [.control, .shift], featureName: "이전 입력 소스", source: "macOS"),

        // Mission Control
        .init(key: .upArrow, modifiers: [.control], featureName: "Mission Control", source: "macOS"),
        .init(key: .downArrow, modifiers: [.control], featureName: "응용 프로그램 윈도우", source: "macOS"),
        .init(key: .leftArrow, modifiers: [.control], featureName: "왼쪽 Space로 이동", source: "macOS"),
        .init(key: .rightArrow, modifiers: [.control], featureName: "오른쪽 Space로 이동", source: "macOS"),

        // App Switcher
        .init(key: .tab, modifiers: [.command], featureName: "앱 전환 (⌘Tab)", source: "macOS"),

        // Common App Shortcuts
        .init(key: .q, modifiers: [.command], featureName: "앱 종료 (⌘Q)", source: "macOS"),
        .init(key: .w, modifiers: [.command], featureName: "창 닫기 (⌘W)", source: "macOS"),
        .init(key: .h, modifiers: [.command], featureName: "앱 숨기기 (⌘H)", source: "macOS"),
        .init(key: .m, modifiers: [.command], featureName: "창 최소화 (⌘M)", source: "macOS"),

        // Clipboard & Edit
        .init(key: .c, modifiers: [.command], featureName: "복사 (⌘C)", source: "macOS"),
        .init(key: .v, modifiers: [.command], featureName: "붙여넣기 (⌘V)", source: "macOS"),
        .init(key: .x, modifiers: [.command], featureName: "잘라내기 (⌘X)", source: "macOS"),
        .init(key: .a, modifiers: [.command], featureName: "전체 선택 (⌘A)", source: "macOS"),
        .init(key: .z, modifiers: [.command], featureName: "실행 취소 (⌘Z)", source: "macOS"),

        // Full Screen
        .init(key: .f, modifiers: [.command, .control], featureName: "전체 화면 전환", source: "macOS")
    ]

    private static let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    /// Check if a shortcut conflicts with known macOS system shortcuts
    static func checkConflict(for shortcut: KeyboardShortcuts.Shortcut) -> ShortcutConflict? {
        let key = shortcut.key
        let shortcutMods = shortcut.modifiers.intersection(relevantFlags)

        for known in knownShortcuts {
            let knownMods = known.modifiers.intersection(relevantFlags)
            if key == known.key, shortcutMods == knownMods {
                return ShortcutConflict(
                    featureName: known.featureName,
                    source: known.source
                )
            }
        }
        return nil
    }
}
