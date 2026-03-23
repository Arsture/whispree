import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var modelManager: ModelManager
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

            Section("STT Provider") {
                Picker("Provider", selection: Binding(
                    get: { appState.settings.sttProviderType },
                    set: { (newValue: STTProviderType) in
                        appState.settings.sttProviderType = newValue
                        appState.settings.save()
                        if newValue == .groq {
                            Task { await appState.switchSTTProvider(to: newValue) }
                        }
                        // .whisperKit and .lightning: only save setting; UI shows download button
                    }
                )) {
                    ForEach(STTProviderType.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                if appState.settings.sttProviderType == .groq {
                    SecureField("Groq API Key", text: Binding(
                        get: { appState.settings.groqApiKey },
                        set: {
                            appState.settings.groqApiKey = $0
                            appState.settings.save()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    if appState.settings.groqApiKey.isEmpty {
                        Label("console.groq.com에서 API Key를 발급받으세요", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label("API Key 설정됨", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                if appState.settings.sttProviderType == .whisperKit || appState.settings.sttProviderType == .lightning {
                    sttModelStatusView
                }
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

                Toggle("Launch at login", isOn: Binding(
                    get: { appState.settings.launchAtLogin },
                    set: {
                        appState.settings.launchAtLogin = $0
                        appState.settings.save()
                    }
                ))
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

    @ViewBuilder
    private var sttModelStatusView: some View {
        switch appState.whisperModelState {
        case .notDownloaded:
            VStack(alignment: .leading, spacing: 6) {
                Label("모델 다운로드가 필요합니다", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("다운로드") {
                    Task {
                        try? await modelManager.downloadWhisperModel()
                        await appState.switchSTTProvider(to: appState.settings.sttProviderType)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        case .downloading(let progress):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                Text("다운로드 중... \(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("모델 로딩 중...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .ready:
            Label("사용 가능", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .error(let msg):
            VStack(alignment: .leading, spacing: 6) {
                Label(msg, systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("재시도") {
                    Task {
                        try? await modelManager.downloadWhisperModel()
                        await appState.switchSTTProvider(to: appState.settings.sttProviderType)
                    }
                }
                .controlSize(.small)
            }
        }
    }

    private func refreshPermissions() {
        micGranted = AudioService().checkPermission()
        axGranted = TextInsertionService.isAccessibilityEnabled()
    }
}
