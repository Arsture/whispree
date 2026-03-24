import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @State private var micGranted = false
    @State private var axGranted = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                // Hotkey Section
                SettingsCard(title: "Hotkey", description: "전역 단축키 설정") {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        SettingsRow(label: "Recording shortcut") {
                            KeyboardShortcuts.Recorder(for: .toggleRecording)
                        }

                        SettingsRow(label: "Quick Fix shortcut") {
                            KeyboardShortcuts.Recorder(for: .quickFix)
                        }

                        Text("텍스트를 선택한 후 Quick Fix 단축키를 누르면 단어를 즉시 교정하고 사전에 저장합니다.")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Recording Mode Section
                SettingsCard(title: "Recording Mode", description: "녹음 동작 방식") {
                    Picker("Mode", selection: Binding(
                        get: { appState.settings.recordingMode },
                        set: { hotkeyManager.updateMode($0) }
                    )) {
                        ForEach(RecordingMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.displayName)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                // Language Section
                SettingsCard(title: "Language", description: "전사 언어 설정") {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Picker("Transcription language", selection: Binding(
                            get: { appState.settings.language },
                            set: {
                                appState.settings.language = $0
                                appState.settings.save()
                            }
                        )) {
                            ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .labelsHidden()

                        if appState.settings.language == .auto {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.statusWarning)
                                Text("Auto-detect may not always work correctly. Select a specific language for better accuracy.")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                    }
                }

                // General Settings
                SettingsCard(title: "General") {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        SettingsRow(label: "Show transcription overlay") {
                            Toggle("", isOn: Binding(
                                get: { appState.settings.showOverlay },
                                set: {
                                    appState.settings.showOverlay = $0
                                    appState.settings.save()
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }

                        SettingsRow(label: "Launch at login") {
                            Toggle("", isOn: Binding(
                                get: { appState.settings.launchAtLogin },
                                set: {
                                    appState.settings.launchAtLogin = $0
                                    appState.settings.save()
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }
                }

                // Permissions Section
                SettingsCard(title: "Permissions", description: "앱 권한 상태") {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        SettingsRow(label: "Microphone", icon: "mic.fill") {
                            if micGranted {
                                StatusBadge("Granted", icon: "checkmark.circle.fill", style: .success)
                            } else {
                                HStack(spacing: 6) {
                                    StatusBadge("Not Granted", icon: "xmark.circle.fill", style: .error)
                                    Button("Request") {
                                        Task {
                                            micGranted = await AudioService().requestPermission()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }

                        SettingsRow(label: "Accessibility", icon: "hand.raised.fill") {
                            if axGranted {
                                StatusBadge("Granted", icon: "checkmark.circle.fill", style: .success)
                            } else {
                                HStack(spacing: 6) {
                                    StatusBadge("Not Granted", icon: "xmark.circle.fill", style: .error)
                                    Button("Open Settings") {
                                        TextInsertionService.requestAccessibilityPermission()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }

                        Button("Refresh Status") {
                            refreshPermissions()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.surfaceBackground)
        .onAppear {
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        micGranted = AudioService().checkPermission()
        axGranted = TextInsertionService.isAccessibilityEnabled()
    }
}
