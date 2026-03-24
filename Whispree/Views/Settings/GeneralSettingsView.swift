import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @State private var micGranted = false
    @State private var axGranted = false

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.sectionSpacing) {
                // Hotkey Section
                SettingsCard(title: "Hotkey") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Recording shortcut:")
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .toggleRecording)
                        }

                        HStack {
                            Text("Quick Fix shortcut:")
                            Spacer()
                            KeyboardShortcuts.Recorder(for: .quickFix)
                        }

                        Text("텍스트를 선택한 후 Quick Fix 단축키를 누르면 단어를 즉시 교정하고 사전에 저장합니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Recording Mode Section
                SettingsCard(title: "Recording Mode") {
                    Picker("Mode", selection: Binding(
                        get: { appState.settings.recordingMode },
                        set: { hotkeyManager.updateMode($0) }
                    )) {
                        ForEach(RecordingMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.displayName)
                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                // Language Section
                SettingsCard(title: "Language") {
                    VStack(spacing: 8) {
                        Picker("Transcription language:", selection: Binding(
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

                        if appState.settings.language == .auto {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.yellow)
                                    .font(.caption2)
                                Text("Auto-detect may not always work correctly. Select a specific language for better accuracy.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                // General Settings
                SettingsCard(title: "General") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Show transcription overlay")
                            Spacer()
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

                        HStack {
                            Text("Launch at login")
                            Spacer()
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
                SettingsCard(title: "Permissions") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Microphone:")
                            Spacer()
                            if micGranted {
                                Label("Granted", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            } else {
                                HStack(spacing: 8) {
                                    Label("Not Granted", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                    Button("Request") {
                                        Task {
                                            micGranted = await AudioService().requestPermission()
                                        }
                                    }
                                    .font(.caption)
                                }
                            }
                        }

                        HStack {
                            Text("Accessibility:")
                            Spacer()
                            if axGranted {
                                Label("Granted", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            } else {
                                HStack(spacing: 8) {
                                    Label("Not Granted", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                    Button("Open Settings") {
                                        TextInsertionService.requestAccessibilityPermission()
                                    }
                                    .font(.caption)
                                }
                            }
                        }

                        HStack {
                            Spacer()
                            Button("Refresh Status") {
                                refreshPermissions()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .padding(DesignTokens.outerPadding)
        }
        .onAppear {
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        micGranted = AudioService().checkPermission()
        axGranted = TextInsertionService.isAccessibilityEnabled()
    }
}
