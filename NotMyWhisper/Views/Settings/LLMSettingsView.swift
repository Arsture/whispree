import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager
    @State private var customPrompt: String = ""

    var body: some View {
        Form {
            Section("LLM Provider") {
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
            }

            if appState.settings.llmProviderType == .openai {
                Section("OpenAI 모델") {
                    Picker("Model", selection: Binding(
                        get: { appState.settings.openaiModel },
                        set: {
                            appState.settings.openaiModel = $0
                            appState.settings.save()
                        }
                    )) {
                        ForEach(OpenAIModel.allCases, id: \.self) { model in
                            VStack(alignment: .leading) {
                                Text(model.displayName)
                                Text(model.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(model)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("OpenAI 인증") {
                    if appState.authService.isLoggedIn {
                        // Codex CLI 인증 활성
                        HStack {
                            Text("인증 방식:")
                            Spacer()
                            Label("Codex CLI", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
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
                        // OAuth 인증 활성
                        HStack {
                            Text("인증 방식:")
                            Spacer()
                            Label("OpenAI 로그인", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                        Button("로그아웃") {
                            appState.oauthService.logout()
                        }
                        .font(.caption)
                    } else {
                        // 미인증 상태
                        Label("로그인이 필요합니다", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
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
                                .foregroundStyle(.red)
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
            }

            if appState.settings.llmProviderType == .local,
               !appState.llmModelState.isReady {
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("모델 탭에서 LLM 모델을 다운로드하세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if appState.settings.llmProviderType != .none {
                Section("Correction Mode") {
                    Picker("Mode", selection: Binding(
                        get: { appState.settings.correctionMode },
                        set: {
                            appState.settings.correctionMode = $0
                            appState.settings.save()
                            loadPromptForMode($0)
                        }
                    )) {
                        ForEach(CorrectionMode.allCases, id: \.self) { mode in
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

                Section("System Prompt") {
                    if appState.settings.correctionMode == .custom {
                        TextEditor(text: $customPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 120)

                        HStack {
                            Spacer()
                            Button("Save Prompt") {
                                appState.settings.customLLMPrompt = customPrompt
                                appState.settings.save()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        Text(currentPromptPreview)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 80, alignment: .topLeading)
                            .padding(4)
                            .background(.quaternary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Text("Switch to \"Custom\" mode to edit the prompt.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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
