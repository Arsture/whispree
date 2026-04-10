import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager
    @State private var customPrompt: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // LLM Provider Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("LLM Provider")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Picker("Provider", selection: Binding(
                        get: { appState.settings.llmProviderType },
                        set: { (newValue: LLMProviderType) in
                            appState.settings.llmProviderType = newValue
                            appState.settings.isLLMEnabled = (newValue != .none)
                            Task { await appState.switchLLMProvider(to: newValue) }
                        }
                    )) {
                        ForEach(LLMProviderType.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .labelsHidden()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.surfaceBackgroundView(cornerRadius: 28))

                // Local Model Picker
                if appState.settings.llmProviderType == .local {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("로컬 모델")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(DeviceCapability.current.chipName) · \(DeviceCapability.current.totalRAMGB) GB")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        // 현재 STT 모델 크기 (조합 계산용)
                        let sttOverhead: Int64 = {
                            switch appState.settings.sttProviderType {
                            case .whisperKit: return 1_500_000_000
                            case .mlxAudio: return 1_000_000_000
                            case .groq: return 0
                            }
                        }()

                        VStack(spacing: 8) {
                            ForEach(LocalModelSpec.supported) { spec in
                                let compat = spec.compatibility(otherModelSizeBytes: sttOverhead)
                                let isSelected = appState.settings.llmModelId == spec.id
                                Button {
                                    appState.settings.llmModelId = spec.id
                                    Task { await appState.switchLLMProvider(to: .local) }
                                } label: {
                                    HStack(alignment: .top) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? DesignTokens.accentPrimary : .secondary)
                                            .font(.title3)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(spec.displayName)
                                                    .font(.headline)
                                                if spec.capability == .vision {
                                                    Image(systemName: "eye")
                                                        .font(.caption2)
                                                        .foregroundStyle(DesignTokens.accentPrimary)
                                                }
                                            }
                                            Text(spec.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        ModelMetricsView(
                                            sizeText: spec.sizeDescription,
                                            ramPercent: compat.ramUsagePercent,
                                            tokPerSec: compat.estimatedTokPerSec,
                                            latencyMs: nil,
                                            qualityScore: spec.qualityScore,
                                            grade: compat.grade
                                        )
                                    }
                                    .padding(16)
                                    .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 22))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .strokeBorder(isSelected ? DesignTokens.accentPrimary.opacity(0.24) : Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let spec = LocalModelSpec.find(appState.settings.llmModelId),
                           spec.capability == .vision {
                            Label("이 모델은 스크린샷 컨텍스트를 활용합니다", systemImage: "eye")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.accentPrimary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.surfaceBackgroundView(cornerRadius: 28))

                    // Screenshot Context Section (Local vision model)
                    if appState.llmProvider?.supportsVision == true {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("스크린샷 컨텍스트")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("활성화")
                                    Text("녹음 시 화면을 캡처하여 교정 정확도를 높입니다")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { appState.settings.isScreenshotContextEnabled },
                                    set: {
                                        appState.settings.isScreenshotContextEnabled = $0
                                        if !$0 { appState.settings.isScreenshotPasteEnabled = false }
                                    }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }

                            if appState.settings.isScreenshotContextEnabled {
                                Divider()

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("에이전트에 전달")
                                        Text("텍스트 삽입 후 캡처된 스크린샷을 대상 앱에 이미지로 붙여넣습니다")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { appState.settings.isScreenshotPasteEnabled },
                                        set: { appState.settings.isScreenshotPasteEnabled = $0 }
                                    ))
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignTokens.surfaceBackgroundView(cornerRadius: 28))
                    }
                }

                // OpenAI Model Section
                if appState.settings.llmProviderType == .openai {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenAI 모델")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            ForEach(OpenAIModel.allCases, id: \.self) { model in
                                let isSelected = appState.settings.openaiModel == model
                                Button {
                                    appState.settings.openaiModel = model
                                } label: {
                                    HStack(alignment: .top) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? DesignTokens.accentPrimary : .secondary)
                                            .font(.title3)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(model.displayName)
                                                .font(.headline)
                                            Text(model.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        ModelMetricsView(
                                            sizeText: "☁️",
                                            ramPercent: nil,
                                            tokPerSec: nil,
                                            latencyMs: model.estimatedLatencyMs,
                                            qualityScore: model.qualityScore,
                                            grade: .runsGreat
                                        )
                                    }
                                    .padding(16)
                                    .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 22))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .strokeBorder(isSelected ? DesignTokens.accentPrimary.opacity(0.24) : Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.surfaceBackgroundView(cornerRadius: 28))

                    // Screenshot Context Section (OpenAI — always vision-capable)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("스크린샷 컨텍스트")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("활성화")
                                Text("녹음 시 화면을 캡처하여 교정 정확도를 높입니다")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.settings.isScreenshotContextEnabled },
                                set: {
                                    appState.settings.isScreenshotContextEnabled = $0
                                    if !$0 { appState.settings.isScreenshotPasteEnabled = false }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }

                        if appState.settings.isScreenshotContextEnabled {
                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("에이전트에 전달")
                                    Text("텍스트 삽입 후 캡처된 스크린샷을 대상 앱에 이미지로 붙여넣습니다")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { appState.settings.isScreenshotPasteEnabled },
                                    set: { appState.settings.isScreenshotPasteEnabled = $0 }
                                ))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.surfaceBackgroundView(cornerRadius: 28))

                    // OpenAI Auth Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenAI 인증")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        if appState.authService.isLoggedIn {
                            // Codex CLI auth active
                            HStack {
                                Text("인증 방식:")
                                Spacer()
                                Label("Codex CLI", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(DesignTokens.textColor(for: .secondary))
                                    .font(.caption)
                            }
                            if let accountId = appState.authService.currentAccountId {
                                HStack {
                                    Text("Account:")
                                    Spacer()
                                    Text(accountId)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if appState.oauthService.isLoggedIn {
                            // OAuth auth active
                            HStack {
                                Text("인증 방식:")
                                Spacer()
                                Label("OpenAI 로그인", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(DesignTokens.textColor(for: .secondary))
                                    .font(.caption)
                            }
                            Button("로그아웃") {
                                appState.oauthService.logout()
                            }
                            .font(.caption)
                        } else {
                            // Not authenticated
                            Label("로그인이 필요합니다", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
                                .font(.caption)

                            Button {
                                Task { await appState.oauthService.startLogin() }
                            } label: {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("OpenAI 로그인")
                                }
                            }
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
                                    .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                                    .font(.caption)
                            }

                            Text("Codex CLI가 설치되어 있으면 자동 감지됩니다")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Codex 인증 확인") {
                                appState.authService.checkAuth()
                            }
                            .font(.caption)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.surfaceBackgroundView(cornerRadius: 28))
                }

                // Model Status Notice
                if appState.settings.llmProviderType == .local,
                   !appState.llmModelState.isReady
                {
                    let isCached = modelManager.modelCacheStates[appState.settings.llmModelId] ?? false
                    HStack(spacing: 8) {
                        if isCached {
                            // 다운로드됨 + 로딩 중
                            ProgressView()
                                .controlSize(.small)
                            Text("모델 로딩 중...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if case .loading = appState.llmModelState {
                            // 다운로드 중
                            ProgressView()
                                .controlSize(.small)
                            Text("모델 다운로드 중...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if case let .error(msg) = appState.llmModelState {
                            // 에러
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                                .lineLimit(2)
                        } else {
                            // 다운로드 필요
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(DesignTokens.accentPrimary)
                            Text("다운로드 탭에서 '\(LocalModelSpec.find(appState.settings.llmModelId)?.displayName ?? "모델")' 을 다운로드하세요.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.surfaceBackgroundView(cornerRadius: 28))
                }

                // Correction Mode Section
                if appState.settings.llmProviderType != .none {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Correction Mode")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        Picker("Mode", selection: Binding(
                            get: { appState.settings.correctionMode },
                            set: {
                                appState.settings.correctionMode = $0
                                loadPromptForMode($0)
                            }
                        )) {
                            ForEach(CorrectionMode.allCases, id: \.self) { mode in
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
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        DesignTokens.surfaceBackgroundView(cornerRadius: 28)
                    )

                    // System Prompt Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Prompt")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        if appState.settings.correctionMode == .custom {
                            TextEditor(text: $customPrompt)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 120)

                            HStack {
                                Spacer()
                                Button("Save Prompt") {
                                    appState.settings.customLLMPrompt = customPrompt
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            ScrollView {
                                Text(currentPromptPreview)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(4)
                                    .textSelection(.enabled)
                            }
                            .frame(height: 200)
                            .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 10))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Text("Switch to \"Custom\" mode to edit the prompt.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DesignTokens.surfaceBackgroundView(cornerRadius: 28))
                }
            }
            .padding(24)
        }
        .onAppear {
            customPrompt = appState.settings.customLLMPrompt
                ?? CorrectionPrompts.defaultSystemPrompt
            appState.authService.checkAuth()
            appState.oauthService.checkAuth()
        }
    }

    private var currentPromptPreview: String {
        CorrectionPrompts.prompt(
            for: appState.settings.correctionMode,
            language: appState.settings.language
        )
    }

    private func loadPromptForMode(_ mode: CorrectionMode) {
        if mode == .custom {
            customPrompt = appState.settings.customLLMPrompt
                ?? CorrectionPrompts.defaultSystemPrompt
        }
    }
}
