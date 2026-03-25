import SwiftUI
import KeyboardShortcuts
import AppKit

struct ShortcutRecorderButton: View {
    let name: KeyboardShortcuts.Name
    @Binding var conflict: ShortcutConflict?

    @EnvironmentObject var hotkeyManager: HotkeyManager
    @StateObject private var recorder = RecorderModel()
    @State private var currentShortcut: KeyboardShortcuts.Shortcut?

    var body: some View {
        Button(action: beginRecording) {
            badge
        }
        .buttonStyle(.plain)
        .popover(isPresented: $recorder.showPopover) {
            popoverBody
                .onDisappear(perform: handleDismiss)
        }
        .onAppear(perform: syncCurrent)
    }

    // MARK: - Badge

    private var badge: some View {
        Group {
            if let s = currentShortcut {
                Text(verbatim: "\(s)")
                    .font(.system(.body, design: .rounded).weight(.medium))
            } else {
                Text("단축키 설정")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
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
                Circle().fill(.red.opacity(0.15)).frame(width: 28, height: 28)
                Circle().fill(.red).frame(width: 10, height: 10)
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
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 28)
            }

            HStack(spacing: 8) {
                if currentShortcut != nil {
                    Button("초기화") { clearShortcut() }
                        .font(.caption)
                }
                Button("취소") { cancelRecording() }
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 240)
    }

    private func conflictContent(shortcut: KeyboardShortcuts.Shortcut, conflict: ShortcutConflict) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.title3)
                Text(verbatim: "\(shortcut)")
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

        recorder.savedShortcut = KeyboardShortcuts.getShortcut(for: name)
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

    private func handleCaptured(_ shortcut: KeyboardShortcuts.Shortcut) {
        if let detectedConflict = ShortcutConflictDetector.checkConflict(for: shortcut) {
            recorder.pendingShortcut = shortcut
            recorder.pendingConflict = detectedConflict
        } else {
            applyShortcut(shortcut)
            conflict = nil
        }
    }

    private func applyShortcut(_ shortcut: KeyboardShortcuts.Shortcut) {
        EventTapHotkeyService.shared.stopRecording()
        KeyboardShortcuts.setShortcut(shortcut, for: name)
        currentShortcut = shortcut
        recorder.showPopover = false
        hotkeyManager.reloadHotkeys()
    }

    private func clearShortcut() {
        EventTapHotkeyService.shared.stopRecording()
        KeyboardShortcuts.setShortcut(nil, for: name)
        currentShortcut = nil
        conflict = nil
        recorder.showPopover = false
        hotkeyManager.reloadHotkeys()
    }

    private func cancelRecording() {
        EventTapHotkeyService.shared.stopRecording()
        recorder.showPopover = false
    }

    private func handleDismiss() {
        EventTapHotkeyService.shared.stopRecording()
        syncCurrent()
    }

    private func syncCurrent() {
        currentShortcut = KeyboardShortcuts.getShortcut(for: name)
        if let s = currentShortcut {
            conflict = ShortcutConflictDetector.checkConflict(for: s)
        } else {
            conflict = nil
        }
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
    @Published var pendingShortcut: KeyboardShortcuts.Shortcut?
    @Published var pendingConflict: ShortcutConflict?
    var savedShortcut: KeyboardShortcuts.Shortcut?
}
