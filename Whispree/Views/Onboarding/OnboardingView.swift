import AVFoundation
import CoreGraphics
import KeyboardShortcuts
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var micGranted = false
    @State private var axGranted = false
    @State private var screenRecordingGranted = false
    @State private var axCheckTimer: Timer?
    @State private var demoText = ""
    @State private var quickFixDemoText = "밸리데이션을 체크해서 컨트롤러의 로직을 리팩토링합니다"

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0 ..< totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? DesignTokens.accentPrimary : DesignTokens.Surface.subdued)
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Group {
                switch currentStep {
                    case 0: welcomeStep
                    case 1: permissionStep
                    case 2: providerSetupStep
                    case 3: recordingGuideStep
                    case 4: quickFixReadyStep
                    default: welcomeStep
                }
            }

            Spacer()
        }
        .frame(width: 480, height: 640)
        .background {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.04),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(DesignTokens.accentPrimary)

            Text("Welcome to Whispree")
                .font(.largeTitle.bold())

            Text("Free, local speech-to-text with AI correction.\nNo cloud. No subscription. Just your voice.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Get Started") {
                withAnimation { currentStep = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 40)
        }
        .padding(24)
    }

    // MARK: - Step 1: Permissions

    private var permissionStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)

            Text("Permissions")
                .font(.title.bold())

            Text("각 항목을 클릭하여 권한을 허용하세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                // Microphone
                Button {
                    Task {
                        micGranted = await AVCaptureDevice.requestAccess(for: .audio)
                        NSApp.activate(ignoringOtherApps: true)
                    }
                } label: {
                    permissionCard(
                        icon: "mic.fill",
                        iconColor: DesignTokens.accentPrimary,
                        title: "마이크",
                        description: "음성 녹음에 필요합니다",
                        isGranted: micGranted
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, 16)

                // Accessibility
                Button {
                    TextInsertionService.requestAccessibilityPermission()
                    startAccessibilityCheck()
                } label: {
                    permissionCard(
                        icon: "hand.raised.fill",
                        iconColor: DesignTokens.accentPrimary,
                        title: "손쉬운 사용",
                        description: "다른 앱에 텍스트를 붙여넣기 위해 필요합니다",
                        isGranted: axGranted
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, 16)

                // Screen Recording
                Button {
                    CGRequestScreenCaptureAccess()
                    screenRecordingGranted = CGPreflightScreenCaptureAccess()
                } label: {
                    permissionCard(
                        icon: "camera.viewfinder",
                        iconColor: DesignTokens.accentPrimary,
                        title: "화면 녹화",
                        description: "다른 앱 화면을 캡처하여 AI 교정의 맥락을 제공합니다",
                        isGranted: screenRecordingGranted
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.horizontal, 16)

                // App Management
                Button {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AppBundles") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    permissionCard(
                        icon: "arrow.triangle.2.circlepath",
                        iconColor: DesignTokens.accentPrimary,
                        title: "앱 관리",
                        description: "자동 업데이트에 필요합니다 (선택)",
                        isGranted: false,
                        actionLabel: "설정 열기"
                    )
                }
                .buttonStyle(.plain)

                Text("설정에서 Whispree를 허용한 후에도 여기에 체크 표시가 나타나지 않습니다")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .padding(.top, -4)
            }
            .background(cardBackground(cornerRadius: 28))

            Spacer()

            navigationButtons(backStep: 0, nextStep: 2, nextLabel: "Continue")
        }
        .padding(24)
        .onAppear {
            micGranted = AudioService().checkPermission()
            axGranted = TextInsertionService.isAccessibilityEnabled()
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        }
        .onDisappear {
            axCheckTimer?.invalidate()
            axCheckTimer = nil
        }
    }

    // MARK: - Step 2: Provider Setup

    private var providerSetupStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(DesignTokens.accentPrimary)

            Text("서비스 연동")
                .font(.title.bold())

            Text("사용할 서비스의 인증을 설정하세요.\n나중에 Settings에서도 변경할 수 있습니다.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                // Groq API Key
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
                            .frame(width: 24)
                        Text("Groq Cloud STT")
                            .font(.headline)
                        Spacer()
                        if !appState.settings.groqApiKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                        } else {
                            Text("선택사항")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("빠른 클라우드 음성 인식을 사용하려면 API Key를 입력하세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SecureField("Groq API Key", text: Binding(
                        get: { appState.settings.groqApiKey },
                        set: { appState.settings.groqApiKey = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                .padding(16)

                Divider().padding(.horizontal, 16)

                // OpenAI OAuth
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                            .frame(width: 24)
                        Text("OpenAI LLM 교정")
                            .font(.headline)
                        Spacer()
                        if appState.authService.isLoggedIn || appState.oauthService.isLoggedIn {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                        } else {
                            Text("선택사항")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("GPT로 전사 결과를 교정하려면 로그인하세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if appState.authService.isLoggedIn {
                            Label("Codex CLI 인증됨", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                    } else if appState.oauthService.isLoggedIn {
                        HStack {
                            Label("로그인됨", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                            Spacer()
                            Button("로그아웃") {
                                appState.oauthService.logout()
                            }
                            .font(.caption)
                        }
                    } else {
                        Button {
                            Task { await appState.oauthService.startLogin() }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                Text("OpenAI 로그인")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(appState.oauthService.isLoggingIn)

                        if appState.oauthService.isLoggingIn {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("브라우저에서 로그인 중...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if let error = appState.oauthService.loginError {
                            Label(error, systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                        }
                    }
                }
                .padding(16)
            }
            .background(cardBackground(cornerRadius: 28))

            Spacer()

            navigationButtons(backStep: 1, nextStep: 3, nextLabel: "Continue")
        }
        .padding(24)
        .onAppear {
            appState.authService.checkAuth()
            appState.oauthService.checkAuth()
        }
    }

    // MARK: - Step 3: Recording Guide

    private var recordingGuideStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "mic.and.signal.meter")
                .font(.system(size: 50))
                .foregroundStyle(DesignTokens.accentPrimary)

            Text("녹음 방법")
                .font(.title.bold())

            Text("녹음 모드를 선택하고 테스트해보세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Mode picker
            VStack(spacing: 0) {
                modeCard(
                    mode: .pushToTalk,
                    icon: "hand.tap.fill",
                    title: "Push to Talk",
                    description: "키를 누르고 있는 동안 녹음, 떼면 전사"
                )
                Divider().padding(.horizontal, 16)
                modeCard(
                    mode: .toggle,
                    icon: "power",
                    title: "Toggle",
                    description: "한 번 눌러 시작, 다시 눌러 중지"
                )
            }
            .background(cardBackground(cornerRadius: 28))

            // Test area
            recordingTestSection

            Spacer()

            navigationButtons(backStep: 2, nextStep: 4, nextLabel: "Continue")
        }
        .padding(24)
        .onAppear { initializeProviders() }
        .onChange(of: appState.transcriptionState) {
            if appState.transcriptionState == .idle, !appState.finalText.isEmpty {
                let result = appState.correctedText.isEmpty ? appState.finalText : appState.correctedText
                withAnimation { demoText = result }
            }
        }
    }

    private var recordingTestSection: some View {
        VStack(spacing: 6) {
            if case .ready = appState.whisperModelState {
                // Active test area
                HStack {
                    recordingStatusIndicator
                    Spacer()
                    shortcutBadge(shortcutText(for: .toggleRecording))
                }

                TextEditor(text: $demoText)
                    .font(.system(.body))
                    .frame(height: 50)
                    .scrollContentBackground(.hidden)
                    .background(insetBackground())
                    .overlay(alignment: .topLeading) {
                        if demoText.isEmpty, appState.transcriptionState == .idle {
                            Text("여기에 전사 결과가 나타납니다")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }

                HStack(spacing: 4) {
                    shortcutBadge("ESC")
                    Text("녹음 중 취소")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            } else if case .loading = appState.whisperModelState {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("STT 프로바이더 준비 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(insetBackground())

            } else {
                VStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("프로바이더 설정 후 대시보드에서 테스트할 수 있습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(insetBackground())
            }
        }
        .padding(16)
        .background(DesignTokens.surfaceBackgroundView(role: .editor, cornerRadius: 28))
    }

    @ViewBuilder
    private var recordingStatusIndicator: some View {
        switch appState.transcriptionState {
            case .recording:
                HStack(spacing: 4) {
                    Circle().fill(DesignTokens.semanticColors(for: .danger).foreground).frame(width: 6, height: 6)
                    Text("녹음 중...")
                        .font(.caption).foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                }
            case .transcribing:
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("전사 중...")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .correcting:
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text("교정 중...")
                        .font(.caption).foregroundStyle(.secondary)
                }
            default:
                if demoText.isEmpty {
                    Text("단축키를 눌러 테스트해보세요")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                        Text("전사 완료!")
                            .font(.caption).foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                    }
                }
        }
    }

    // MARK: - Step 4: Quick Fix & Ready

    private var quickFixReadyStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "character.textbox")
                .font(.system(size: 50))
                .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)

            Text("Quick Fix")
                .font(.title.bold())

            Text("잘못 전사된 단어를 바로 교정하고\n사전에 등록하세요")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // How-to steps
            VStack(alignment: .leading, spacing: 10) {
                quickFixStepRow(number: 1, text: "교정할 텍스트를 드래그하여 선택")
                quickFixStepRow(number: 2, text: "\(shortcutText(for: .quickFix))을 눌러 Quick Fix 호출")
                quickFixStepRow(number: 3, text: "올바른 단어를 입력하고 저장")
                quickFixStepRow(number: 4, text: "사전에 등록 → 다음부터 자동 교정")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(cornerRadius: 28))

            // Test area
            VStack(spacing: 6) {
                HStack {
                    Text("아래에서 단어를 선택하고 테스트해보세요")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.accentPrimary)
                    Spacer()
                    shortcutBadge(shortcutText(for: .quickFix))
                }

                TextEditor(text: $quickFixDemoText)
                    .font(.system(.body))
                    .frame(height: 50)
                    .scrollContentBackground(.hidden)
                    .background(insetBackground())
            }
            .padding(16)
            .background(DesignTokens.surfaceBackgroundView(role: .editor, cornerRadius: 28))

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation { currentStep = 3 }
                }
                Spacer()
                Button("시작하기") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 40)
        }
        .padding(24)
    }

    // MARK: - Helpers

    private func navigationButtons(backStep: Int, nextStep: Int, nextLabel: String) -> some View {
        HStack {
            Button("Back") {
                withAnimation { currentStep = backStep }
            }

            Spacer()

            Button(nextLabel) {
                withAnimation { currentStep = nextStep }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.bottom, 40)
    }

    private func permissionCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        isGranted: Bool,
        actionLabel: String = "허용하기"
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
            } else {
                Text(actionLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(iconColor)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 18))
        .contentShape(Rectangle())
    }

    private func modeCard(mode: RecordingMode, icon: String, title: String, description: String) -> some View {
        Button {
            hotkeyManager.updateMode(mode)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            appState.settings.recordingMode == mode
                                ? DesignTokens.interactionColors(for: .selection).background
                                : Color.white.opacity(0.08)
                        )
                        .frame(width: 40, height: 40)
                        .overlay {
                            Circle()
                                .stroke(
                                    appState.settings.recordingMode == mode
                                        ? DesignTokens.interactionColors(for: .selection).border
                                        : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        }
                    Image(systemName: icon)
                        .foregroundStyle(appState.settings.recordingMode == mode ? DesignTokens.accentPrimary : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: appState.settings.recordingMode == mode ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(appState.settings.recordingMode == mode ? DesignTokens.accentPrimary : .secondary.opacity(0.5))
                    .font(.title3)
            }
            .padding(14)
            .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 18))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func quickFixStepRow(number: Int, text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(DesignTokens.semanticColors(for: .warning).foreground)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
        }
    }

    private func shortcutBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .rounded).bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 10))
    }

    private func cardBackground(cornerRadius: CGFloat = DesignTokens.Radius.xxl) -> some View {
        DesignTokens.surfaceBackgroundView(role: .editor, cornerRadius: cornerRadius)
    }

    private func insetBackground(cornerRadius: CGFloat = 18) -> some View {
        DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: cornerRadius)
    }

    private func shortcutText(for name: KeyboardShortcuts.Name) -> String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
            return "\(shortcut)"
        }
        if name == .toggleRecording { return "⌃⇧R" }
        if name == .quickFix { return "⌃⇧D" }
        return "?"
    }

    private func startAccessibilityCheck() {
        axCheckTimer?.invalidate()
        axCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let granted = TextInsertionService.isAccessibilityEnabled()
                if granted {
                    axGranted = true
                    axCheckTimer?.invalidate()
                    axCheckTimer = nil
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func initializeProviders() {
        // Auto-select providers based on step 2 configuration
        if !appState.settings.groqApiKey.isEmpty {
            appState.settings.sttProviderType = .groq
        }
        if appState.authService.isLoggedIn || appState.oauthService.isLoggedIn {
            appState.settings.llmProviderType = .openai
        }

        // Initialize providers for the demo
        Task {
            await appState.switchSTTProvider(to: appState.settings.sttProviderType)
            await appState.switchLLMProvider(to: appState.settings.llmProviderType)
        }
    }
}
