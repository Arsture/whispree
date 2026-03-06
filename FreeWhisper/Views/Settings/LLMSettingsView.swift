import SwiftUI

struct LLMSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var customPrompt: String = ""

    var body: some View {
        Form {
            Section("Text Correction") {
                Toggle("Enable LLM correction", isOn: Binding(
                    get: { appState.settings.isLLMEnabled },
                    set: {
                        appState.settings.isLLMEnabled = $0
                        appState.settings.save()
                    }
                ))
            }

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
                .disabled(!appState.settings.isLLMEnabled)
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
        .formStyle(.grouped)
        .padding()
        .onAppear {
            customPrompt = appState.settings.customLLMPrompt
                ?? CorrectionPrompts.defaultSystemPrompt
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
