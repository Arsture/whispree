import AVFoundation
import CoreGraphics
import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @State private var micGranted = false
    @State private var axGranted = false
    @State private var screenRecordingGranted = false
    @State private var recordingConflict: ShortcutConflict?
    @State private var quickFixConflict: ShortcutConflict?
    @State private var inputChannelCount: Int = 1

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.sectionSpacing) {
                // Hotkey Section
                SettingsCard(title: "Hotkey") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Recording shortcut:")
                            Spacer()
                            ShortcutRecorderButton(
                                name: .toggleRecording,
                                conflict: $recordingConflict
                            )
                        }
                        if let conflict = recordingConflict {
                            shortcutConflictBanner(conflict)
                        }

                        HStack {
                            Text("Quick Fix shortcut:")
                            Spacer()
                            ShortcutRecorderButton(
                                name: .quickFix,
                                conflict: $quickFixConflict
                            )
                        }
                        if let conflict = quickFixConflict {
                            shortcutConflictBanner(conflict)
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

                // Audio Input Channel Section (다채널 장치일 때만 표시)
                if inputChannelCount > 1 {
                    SettingsCard(title: "Audio Input") {
                        VStack(spacing: 8) {
                            Picker("입력 채널:", selection: Binding(
                                get: { appState.settings.audioInputChannel },
                                set: { appState.settings.audioInputChannel = $0 }
                            )) {
                                Text("자동 (모든 채널 다운믹스)").tag(0)
                                ForEach(1 ... inputChannelCount, id: \.self) { ch in
                                    Text("채널 \(ch)").tag(ch)
                                }
                            }

                            Text("외장 오디오 인터페이스에서 마이크가 연결된 채널을 선택하세요. 다음 녹음부터 적용됩니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                // Language Section
                SettingsCard(title: "Language") {
                    VStack(spacing: 8) {
                        Picker("Transcription language:", selection: Binding(
                            get: { appState.settings.language },
                            set: { appState.settings.language = $0 }
                        )) {
                            ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }

                        if appState.settings.language == .auto {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
                                    .font(.caption2)
                                Text("Auto-detect may not always work correctly. Select a specific language for better accuracy.")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
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
                                set: { appState.settings.showOverlay = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }

                        HStack {
                            Text("Launch at login")
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.settings.launchAtLogin },
                                set: { appState.settings.launchAtLogin = $0 }
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
                                    .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                                    .font(.caption)
                            } else {
                                HStack(spacing: 8) {
                                    Label("Not Granted", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
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
                                    .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                                    .font(.caption)
                            } else {
                                HStack(spacing: 8) {
                                    Label("Not Granted", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                                        .font(.caption)
                                    Button("Open Settings") {
                                        TextInsertionService.requestAccessibilityPermission()
                                    }
                                    .font(.caption)
                                }
                            }
                        }

                        HStack {
                            Text("화면 녹화:")
                            Spacer()
                            if screenRecordingGranted {
                                Label("Granted", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                                    .font(.caption)
                            } else {
                                HStack(spacing: 8) {
                                    Label("Not Granted", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                                        .font(.caption)
                                    Button("권한 요청") {
                                        CGRequestScreenCaptureAccess()
                                    }
                                    .font(.caption)
                                }
                            }
                        }

                        HStack {
                            Text("App Management:")
                            Spacer()
                            Button("Open Settings") {
                                if let url =
                                    URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AppBundles")
                                {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .font(.caption)
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
            let engine = AVAudioEngine()
            inputChannelCount = max(1, Int(engine.inputNode.outputFormat(forBus: 0).channelCount))
        }
    }

    private func shortcutConflictBanner(_ conflict: ShortcutConflict) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
                .font(.caption2)
            Text("\(conflict.source)의 '\(conflict.featureName)' 기능을 override 중입니다. 다른 단축키로 변경하면 기존 기능이 자동 복구됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 4)
    }

    private func refreshPermissions() {
        micGranted = AudioService().checkPermission()
        axGranted = TextInsertionService.isAccessibilityEnabled()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }
}
