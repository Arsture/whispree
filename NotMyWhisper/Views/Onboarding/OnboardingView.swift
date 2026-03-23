import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var micGranted = false
    @State private var axGranted = false
    @State private var axCheckTimer: Timer?

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Content
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: permissionStep
                case 2: providerSetupStep
                case 3: readyStep
                default: welcomeStep
                }
            }

            Spacer()
        }
        .frame(width: 480, height: 560)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Welcome to NotMyWhisper")
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
                .foregroundStyle(.orange)

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
                        iconColor: .blue,
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
                        iconColor: .blue,
                        title: "손쉬운 사용",
                        description: "다른 앱에 텍스트를 붙여넣기 위해 필요합니다",
                        isGranted: axGranted
                    )
                }
                .buttonStyle(.plain)
            }
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            navigationButtons(backStep: 0, nextStep: 2, nextLabel: "Continue")
        }
        .padding(24)
        .onAppear {
            micGranted = AudioService().checkPermission()
            axGranted = TextInsertionService.isAccessibilityEnabled()
        }
        .onDisappear {
            axCheckTimer?.invalidate()
            axCheckTimer = nil
        }
    }

    // MARK: - Step 2: Provider Setup (Groq API + OpenAI OAuth)

    private var providerSetupStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

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
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        Text("Groq Cloud STT")
                            .font(.headline)
                        Spacer()
                        if !appState.settings.groqApiKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
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
                        set: {
                            appState.settings.groqApiKey = $0
                            appState.settings.save()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
                .padding(16)

                Divider().padding(.horizontal, 16)

                // OpenAI OAuth
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        Text("OpenAI LLM 교정")
                            .font(.headline)
                        Spacer()
                        if appState.authService.isLoggedIn || appState.oauthService.isLoggedIn {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
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
                            .foregroundStyle(.green)
                    } else if appState.oauthService.isLoggedIn {
                        HStack {
                            Label("로그인됨", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
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
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(16)
            }
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            navigationButtons(backStep: 1, nextStep: 3, nextLabel: "Continue")
        }
        .padding(24)
        .onAppear {
            appState.authService.checkAuth()
            appState.oauthService.checkAuth()
        }
    }

    // MARK: - Step 3: Ready

    private var readyStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("준비 완료!")
                .font(.largeTitle.bold())

            Text("**Control+Shift+R**을 누르면 받아쓰기가 시작됩니다.\n텍스트가 커서 위치에 자동으로 입력됩니다.\n\n단축키는 대시보드에서 변경할 수 있습니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation { currentStep = 2 }
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

    private func permissionCard(icon: String, iconColor: Color, title: String, description: String, isGranted: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
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
                    .foregroundStyle(.green)
            } else {
                Text("허용하기")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(iconColor)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .contentShape(Rectangle())
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
}
