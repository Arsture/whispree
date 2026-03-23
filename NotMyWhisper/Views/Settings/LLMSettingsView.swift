import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appState: AppState
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
                    HStack {
                        Text("로그인 상태:")
                        Spacer()
                        if appState.authService.isLoggedIn {
                            Label("로그인됨", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            if let accountId = appState.authService.currentAccountId {
                                Text(accountId)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Label("로그인 필요", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }

                    Button("로그인 (Codex CLI)") {
                        let task = Process()
                        task.launchPath = "/usr/bin/env"
                        task.arguments = ["codex", "login"]
                        task.launch()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            appState.authService.checkAuth()
                        }
                    }
                    .disabled(appState.authService.isLoggedIn)

                    Button("상태 새로고침") {
                        appState.authService.checkAuth()
                    }
                    .font(.caption)
                }
            }

            if appState.settings.llmProviderType == .local {
                Section("로컬 LLM 모델") {
                    ModelRow(
                        name: "Qwen3 4B Instruct (4-bit)",
                        description: "한국어/영어 텍스트 교정",
                        size: "~2.5 GB",
                        state: appState.llmModelState,
                        downloadProgress: appState.llmDownloadProgress,
                        onDownload: {
                            Task { await appState.switchLLMProvider(to: .local) }
                        },
                        onDelete: {}
                    )
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
