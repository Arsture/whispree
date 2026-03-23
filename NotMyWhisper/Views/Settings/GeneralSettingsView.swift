import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @State private var micGranted = false
    @State private var axGranted = false

    var body: some View {
        Form {
            Section("Hotkey") {
                HStack {
                    Text("Recording shortcut:")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleRecording)
                }
            }

            Section("Recording Mode") {
                Picker("Mode", selection: Binding(
                    get: { appState.settings.recordingMode },
                    set: { hotkeyManager.updateMode($0) }
                )) {
                    ForEach(RecordingMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
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

            Section("Language") {
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
                    Text("Auto-detect may not always work correctly. Select a specific language for better accuracy.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("General") {
                Toggle("Show transcription overlay", isOn: Binding(
                    get: { appState.settings.showOverlay },
                    set: {
                        appState.settings.showOverlay = $0
                        appState.settings.save()
                    }
                ))
                .toggleStyle(.switch)

                Toggle("Launch at login", isOn: Binding(
                    get: { appState.settings.launchAtLogin },
                    set: {
                        appState.settings.launchAtLogin = $0
                        appState.settings.save()
                    }
                ))
                .toggleStyle(.switch)
            }

            Section("Permissions") {
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

                Button("Refresh Status") {
                    refreshPermissions()
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        micGranted = AudioService().checkPermission()
        axGranted = TextInsertionService.isAccessibilityEnabled()
    }
}
