import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager
    @State private var customPrompt: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                // LLM Provider Section
                SettingsCard(title: "LLM Provider", description: "텍스트 교정 엔진") {
                    Picker("Provider", selection: Binding(
                        get: { appState.settings.llmProviderType },
                        set: { (newValue: LLMProviderType) in
                            appState.settings.llmProviderType = newValue
                            appState.settings.isLLMEnabled = (newValue != .none)
                            appState.settings.save()
                            Task { await appState.switchLLMProvider(to: newValue) }
                        }
                    )) {
                        ForEach(LLMProviderType.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .labelsHidden()
                }

                // OpenAI Model Section
                if appState.settings.llmProviderType == .openai {
                    SettingsCard(title: "OpenAI 모델") {
                        Picker("Model", selection: Binding(
                            get: { appState.settings.openaiModel },
                            set: {
                                appState.settings.openaiModel = $0
                                appState.settings.save()
                            }
                        )) {
                            ForEach(OpenAIModel.allCases, id: \.self) { model in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.displayName)
                                    Text(model.description)
                                        .font(.caption)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                                .tag(model)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }

                    // OpenAI Auth Section
                    SettingsCard(title: "OpenAI 인증") {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            if appState.authService.isLoggedIn {
                                // Codex CLI auth active
                                SettingsRow(label: "인증 방식") {
                                    StatusBadge("Codex CLI", icon: "checkmark.circle.fill", style: .success)
                                }
                                if let accountId = appState.authService.currentAccountId {
                                    SettingsRow(label: "Account") {
                                        Text(accountId)
                                            .font(.caption)
                                            .foregroundStyle(DesignTokens.textSecondary)
                                    }
                                }
                            } else if appState.oauthService.isLoggedIn {
                                // OAuth auth active
                                SettingsRow(label: "인증 방식") {
                                    StatusBadge("OpenAI 로그인", icon: "checkmark.circle.fill", style: .success)
                                }
                                Button("로그아웃") {
                                    appState.oauthService.logout()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            } else {
                                // Not authenticated
                                StatusBadge("로그인이 필요합니다", icon: "exclamationmark.triangle.fill", style: .warning)
                                    .padding(.bottom, DesignTokens.Spacing.xs)

                                Button {
                                    Task { await appState.oauthService.startLogin() }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "globe")
                                        Text("OpenAI 로그인")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(appState.oauthService.isLoggingIn)

                                if appState.oauthService.isLoggingIn {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .controlSize(.small)
                                        Text("브라우저에서 로그인 중...")
                                            .font(.caption)
                                            .foregroundStyle(DesignTokens.textSecondary)
                                    }
                                }

                                if let error = appState.oauthService.loginError {
                                    StatusBadge(error, icon: "xmark.circle.fill", style: .error)
                                }

                                Text("Codex CLI가 설치되어 있으면 자동 감지됩니다")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.textTertiary)
                                    .padding(.top, DesignTokens.Spacing.xs)

                                Button("Codex 인증 확인") {
                                    appState.authService.checkAuth()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                // Model Download Notice
                if appState.settings.llmProviderType == .local,
                   !appState.llmModelState.isReady {
                    SettingsCard {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(DesignTokens.statusInfo)
                            Text("모델 탭에서 LLM 모델을 다운로드하세요.")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }

                // Correction Mode Section
                if appState.settings.llmProviderType != .none {
                    SettingsCard(title: "Correction Mode", description: "교정 방식") {
                        Picker("Mode", selection: Binding(
                            get: { appState.settings.correctionMode },
                            set: {
                                appState.settings.correctionMode = $0
                                appState.settings.save()
                                loadPromptForMode($0)
                            }
                        )) {
                            ForEach(CorrectionMode.allCases, id: \.self) { mode in
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

                    // System Prompt Section
                    SettingsCard(title: "System Prompt") {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            if appState.settings.correctionMode == .custom {
                                TextEditor(text: $customPrompt)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(minHeight: 120)
                                    .padding(DesignTokens.Spacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                            .fill(Color(nsColor: .textBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                            .strokeBorder(DesignTokens.textTertiary.opacity(0.2), lineWidth: 1)
                                    )

                                Button("Save Prompt") {
                                    appState.settings.customLLMPrompt = customPrompt
                                    appState.settings.save()
                                }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                Text(currentPromptPreview)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(DesignTokens.textSecondary)
                                    .frame(minHeight: 80, alignment: .topLeading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(DesignTokens.Spacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                                            .fill(DesignTokens.textTertiary.opacity(0.05))
                                    )

                                Text("Switch to \"Custom\" mode to edit the prompt.")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.surfaceBackground)
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
