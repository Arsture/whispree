import KeyboardShortcuts
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @ObservedObject private var permissions = PermissionManager.shared
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
                    VStack(alignment: .leading, spacing: 12) {
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

                        Divider()

                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("녹음 중 음악 일시정지")
                                Text("Apple Music, Spotify, YouTube 등 재생 중인 미디어를 녹음 시작 시 자동으로 일시정지하고 종료 시 재개합니다.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.settings.pauseMediaDuringRecording },
                                set: { appState.settings.pauseMediaDuringRecording = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                    }
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

                // Terminal Restoration Section
                SettingsCard(title: "터미널 복원") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("iTerm2 pane · tmux 위치 자동 복원")
                                Text("녹음 시작 전 iTerm2 session(split)과 tmux window/pane 위치를 기억했다가 전사 후 같은 pane으로 돌아가 붙여넣습니다.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.settings.restoreTerminalContext },
                                set: { appState.settings.restoreTerminalContext = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }

                        if appState.settings.restoreTerminalContext {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 4) {
                                    Text("🖥️")
                                    Text("iTerm2 자동화 권한이 필요합니다:")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("• 첫 녹음 시 macOS가 \"Whispree가 iTerm을 제어\" 권한을 요청하면 허용")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("• tmux 사용자는 기본 소켓(`tmux`/`tmux -L default`)에서만 동작. 커스텀 `-L`/`-S` 소켓은 미지원")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("• Terminal.app, Alacritty, Kitty, Ghostty, Warp 등은 아직 미지원 (앱 포커스만 복원)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 20)
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
                    VStack(spacing: 0) {
                        PermissionRow(
                            icon: "mic.fill",
                            title: "Microphone",
                            subtitle: "음성 녹음에 필요합니다",
                            status: permissions.microphone
                        ) {
                            Task { _ = await PermissionManager.shared.requestMicrophone() }
                        }

                        Divider().padding(.horizontal, 16)

                        PermissionRow(
                            icon: "hand.raised.fill",
                            title: "Accessibility",
                            subtitle: "다른 앱에 텍스트를 붙여넣기 위해 필요합니다",
                            status: permissions.accessibility
                        ) {
                            PermissionManager.shared.requestAccessibility()
                        }

                        Divider().padding(.horizontal, 16)

                        PermissionRow(
                            icon: "camera.viewfinder",
                            title: "화면 녹화",
                            subtitle: "다른 앱 화면을 캡처하여 AI 교정의 맥락을 제공합니다",
                            status: permissions.screenRecording
                        ) {
                            Task { _ = await PermissionManager.shared.requestScreenRecording() }
                        }

                        Divider().padding(.horizontal, 16)

                        PermissionRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "App Management",
                            subtitle: "자동 업데이트에 필요합니다 (선택)",
                            status: .notDetermined,
                            actionLabel: "설정 열기"
                        ) {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AppBundles") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }

                // Automation Section
                SettingsCard(title: "Automation 권한") {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("앱 제어 권한은 해당 기능을 처음 사용할 때 자동으로 요청됩니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                        ForEach(Array(AutomationTarget.all.enumerated()), id: \.element.bundleID) { index, target in
                            let status = permissions.automation[target.bundleID] ?? .notDetermined
                            PermissionRow(
                                icon: target.icon,
                                title: target.name,
                                subtitle: target.description,
                                status: status
                            ) {
                                if status == .denied {
                                    PermissionManager.shared.openSystemSettings(for: .automation(bundleID: target.bundleID))
                                } else {
                                    Task { _ = await PermissionManager.shared.requestAutomation(bundleID: target.bundleID) }
                                }
                            }
                            if index < AutomationTarget.all.count - 1 {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.outerPadding)
        }
        .task {
            // 권한 갱신은 PermissionManager가 5초 타이머 + app-active 훅으로 자동 처리.
            // 탭 진입마다 동기 TCC syscall(AXIsProcessTrusted, CGPreflightScreenCaptureAccess)을 돌리면
            // 체감 가능한 렉이 생기므로 여기서는 채널 탐지만 비동기로 로드.
            inputChannelCount = await Task.detached { AudioService.defaultInputChannelCount() }.value
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

}
