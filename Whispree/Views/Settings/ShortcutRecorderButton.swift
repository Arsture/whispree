import AppKit
import KeyboardShortcuts
import SwiftUI

/// AppSettings의 어떤 단축키 필드를 녹화할지 지정.
enum WhispreeShortcutKind {
    case toggleRecording
    case quickFix

    var displayTitle: String {
        switch self {
            case .toggleRecording: "Recording"
            case .quickFix: "Quick Fix"
        }
    }
}

struct ShortcutRecorderButton: View {
    let kind: WhispreeShortcutKind
    @Binding var conflict: ShortcutConflict?

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @StateObject private var recorder = RecorderModel()

    private var currentShortcut: WhispreeShortcut {
        switch kind {
            case .toggleRecording: appState.settings.toggleRecordingShortcut
            case .quickFix: appState.settings.quickFixShortcut
        }
    }

    var body: some View {
        Button(action: beginRecording) {
            badge
        }
        .buttonStyle(.plain)
        .popover(isPresented: $recorder.showPopover) {
            popoverBody
                .onDisappear(perform: handleDismiss)
        }
        .onAppear(perform: syncConflict)
    }

    // MARK: - Badge

    private var badge: some View {
        Text(verbatim: currentShortcut.displayLabel)
            .font(.system(.body, design: .rounded).weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.separator, lineWidth: 0.5))
    }

    // MARK: - Popover

    @ViewBuilder
    private var popoverBody: some View {
        if let shortcut = recorder.pendingShortcut, let detectedConflict = recorder.pendingConflict {
            conflictContent(shortcut: shortcut, conflict: detectedConflict)
        } else {
            recordingContent
        }
    }

    private var recordingContent: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(DesignTokens.semanticColors(for: .danger).background).frame(width: 28, height: 28)
                Circle().fill(DesignTokens.semanticColors(for: .danger).foreground).frame(width: 10, height: 10)
            }

            Text("새 단축키를 입력하세요")
                .font(.headline)

            if recorder.liveModifiers.isEmpty {
                Text("조합키 + 일반키")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.tertiary)
                    .frame(height: 28)
            } else {
                Text(verbatim: recorder.liveModifiers)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(DesignTokens.accentPrimary)
                    .frame(height: 28)
            }

            Text("modifier 하나만 누르고 떼면 단독 키 바인딩 (예: R⌥)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Button("기본값") { resetToDefault() }
                    .font(.caption)
                Button("취소") { cancelRecording() }
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 260)
    }

    private func conflictContent(shortcut: WhispreeShortcut, conflict: ShortcutConflict) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
                    .font(.title3)
                Text(verbatim: shortcut.displayLabel)
                    .font(.system(.title3, design: .rounded).bold())
            }

            Text("\(conflict.source)의 '\(conflict.featureName)'\n기능을 override합니다.\n다른 단축키로 변경 시 자동 복구됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Button("다시 입력") {
                    recorder.pendingShortcut = nil
                    recorder.pendingConflict = nil
                    startEventTapRecording()
                }
                .buttonStyle(.bordered)

                Button("사용하기") {
                    applyShortcut(shortcut)
                    self.conflict = conflict
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 260)
    }

    // MARK: - Actions

    private func beginRecording() {
        guard AXIsProcessTrusted() else {
            // Prompt accessibility permission
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }

        recorder.pendingShortcut = nil
        recorder.pendingConflict = nil
        recorder.liveModifiers = ""
        recorder.showPopover = true
        startEventTapRecording()
    }

    private func startEventTapRecording() {
        let service = EventTapHotkeyService.shared
        service.startRecording(
            onCapture: { [self] shortcut in
                handleCaptured(shortcut)
            },
            onCancel: { [self] in
                cancelRecording()
            },
            onModifiers: { [self] mods in
                recorder.liveModifiers = formatModifiers(mods)
            }
        )
    }

    private func handleCaptured(_ shortcut: WhispreeShortcut) {
        if let detectedConflict = ShortcutConflictDetector.checkConflict(for: shortcut) {
            recorder.pendingShortcut = shortcut
            recorder.pendingConflict = detectedConflict
        } else {
            applyShortcut(shortcut)
            conflict = nil
        }
    }

    private func applyShortcut(_ shortcut: WhispreeShortcut) {
        EventTapHotkeyService.shared.stopRecording()
        writeShortcut(shortcut)
        recorder.showPopover = false
        hotkeyManager.reloadHotkeys()
    }

    private func resetToDefault() {
        EventTapHotkeyService.shared.stopRecording()
        let defaultShortcut: WhispreeShortcut = switch kind {
            case .toggleRecording: .defaultToggleRecording
            case .quickFix: .defaultQuickFix
        }
        writeShortcut(defaultShortcut)
        conflict = ShortcutConflictDetector.checkConflict(for: defaultShortcut)
        recorder.showPopover = false
        hotkeyManager.reloadHotkeys()
    }

    private func writeShortcut(_ shortcut: WhispreeShortcut) {
        switch kind {
            case .toggleRecording: appState.settings.toggleRecordingShortcut = shortcut
            case .quickFix: appState.settings.quickFixShortcut = shortcut
        }
    }

    private func cancelRecording() {
        EventTapHotkeyService.shared.stopRecording()
        recorder.showPopover = false
    }

    private func handleDismiss() {
        EventTapHotkeyService.shared.stopRecording()
        syncConflict()
    }

    private func syncConflict() {
        conflict = ShortcutConflictDetector.checkConflict(for: currentShortcut)
    }

    private func formatModifiers(_ flags: NSEvent.ModifierFlags) -> String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s
    }
}

// MARK: - Recorder Model

private final class RecorderModel: ObservableObject {
    @Published var showPopover = false
    @Published var liveModifiers = ""
    @Published var pendingShortcut: WhispreeShortcut?
    @Published var pendingConflict: ShortcutConflict?
}
