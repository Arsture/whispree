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
    @State private var syncStatusMessage: String?

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
                                kind: .toggleRecording,
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
                                kind: .quickFix,
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
                    VStack(alignment: .leading, spacing: 8) {
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

                // Dictionary Sync
                SettingsCard(title: "Dictionary Sync") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("사전 동기화")
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.settings.sharedDictionaryEnabled },
                                set: {
                                    appState.settings.sharedDictionaryEnabled = $0
                                    if $0 {
                                        appState.settings.importSharedDictionary()
                                        appState.settings.exportSharedDictionary()
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }

                        Text("Quick Fix 단어와 도메인 단어 세트를 iCloud Drive로 자동 동기화합니다. Dropbox 등 다른 동기화 폴더를 사용하려면 사용자 정의 경로를 지정하세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("사용자 정의 경로")
                                .foregroundStyle(appState.settings.sharedDictionaryEnabled ? .primary : .secondary)

                            TextField("비워두면 iCloud Drive 사용", text: Binding(
                                get: { appState.settings.sharedDictionaryPath ?? "" },
                                set: { appState.settings.sharedDictionaryPath = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .disabled(!appState.settings.sharedDictionaryEnabled)

                            if appState.settings.sharedDictionaryEnabled,
                               let url = appState.settings.sharedDictionaryConfig.resolvedFileURL {
                                Text(url.path)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            } else if appState.settings.sharedDictionaryEnabled {
                                Text("iCloud Drive를 사용할 수 없습니다. 사용자 정의 경로를 지정하세요.")
                                    .font(.caption2)
                                    .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
                            }
                        }

                        HStack(spacing: 8) {
                            Button("지금 가져오기") {
                                let success = appState.settings.importSharedDictionary()
                                showSyncStatus(success ? "가져오기 완료" : "가져올 파일이 없습니다")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("지금 내보내기") {
                                appState.settings.exportSharedDictionary()
                                showSyncStatus("내보내기 완료")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            if let message = syncStatusMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                        .disabled(!appState.settings.sharedDictionaryEnabled)
                    }
                }

                // Browser Restoration Section
                SettingsCard(title: "브라우저 복원") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chrome 탭 및 입력 필드 자동 복원")
                                Text("녹음 시작 전 Chrome 탭과 포커스된 입력 필드를 기억했다가 전사 후 같은 위치로 돌아가 붙여넣습니다.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.settings.restoreBrowserTab },
                                set: { appState.settings.restoreBrowserTab = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }

                        if appState.settings.restoreBrowserTab {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Text("🧭")
                                    Text("Chrome 입력 필드 복원을 사용하려면 Chrome에서 한 번만 설정해주세요:")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("1. Chrome 메뉴바 → 보기 → 개발자 → \"Apple Events로부터 JavaScript 허용\" 체크")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("2. 첫 녹음 시 macOS가 \"Whispree가 Chrome을 제어\" 권한을 요청하면 허용")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 20)
                                Text("설정하지 않으면 탭 복원만 동작하고, 입력 필드 포커스는 복원되지 않습니다.")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DesignTokens.Surface.subdued)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                                    .stroke(DesignTokens.Border.subtle, lineWidth: 1)
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

    private func showSyncStatus(_ message: String) {
        withAnimation { syncStatusMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { syncStatusMessage = nil }
        }
    }

    private func refreshPermissions() {
        micGranted = AudioService().checkPermission()
        axGranted = TextInsertionService.isAccessibilityEnabled()
        screenRecordingGranted = CGPreflightScreenCaptureAccess()
    }
}
