import SwiftUI

enum QuickFixMode: String, CaseIterable {
    case wordOnly = "단어 추가"
    case mapping = "매핑 추가"

    var description: String {
        switch self {
            case .wordOnly: "STT + LLM 사전에 단어 추가"
            case .mapping: "LLM 교정 매핑 추가 (STT 미적용)"
        }
    }
}

struct QuickFixPanelView: View {
    let originalText: String
    let onConfirmWord: (String) -> Void
    let onConfirmMapping: (String, String) -> Void
    let onCancel: () -> Void

    @State private var correctedText = ""
    @State private var mode: QuickFixMode = .mapping
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Image(systemName: "character.textbox")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.accentPrimary)
                Text("Quick Fix")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Mode picker
            Picker("모드", selection: $mode) {
                ForEach(QuickFixMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Text(mode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Original text
            panelSection {
                VStack(alignment: .leading, spacing: 8) {
                    Text("선택된 텍스트")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)

                    Text(originalText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Correction input
            panelSection {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode == .mapping ? "교정할 단어" : "추가할 단어")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)

                    TextField("올바른 단어를 입력하세요", text: $correctedText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            confirmIfValid()
                        }
                }
            }

            if mode == .mapping {
                panelSection {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("저장될 매핑")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)

                        Label("\"\(originalText)\" → \"\(correctedText.isEmpty ? "..." : correctedText)\"", systemImage: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.accentPrimary)
                    }
                }
            }

            Divider()

            // Buttons
            HStack {
                Text(mode == .mapping ? "LLM 교정 매핑으로 저장" : "STT+LLM 사전에 저장")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("취소") { onCancel() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button("저장 및 교정") {
                    confirmIfValid()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .disabled(correctedText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            isTextFieldFocused = true
        }
    }

    private func panelSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DesignTokens.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignTokens.Surface.cardTint)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DesignTokens.Border.subtle, lineWidth: 1)
                }
        )
    }

    private func confirmIfValid() {
        let trimmed = correctedText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        switch mode {
            case .wordOnly:
                onConfirmWord(trimmed)
            case .mapping:
                onConfirmMapping(originalText, trimmed)
        }
    }
}
