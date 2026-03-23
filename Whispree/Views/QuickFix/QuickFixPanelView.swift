import SwiftUI

enum QuickFixMode: String, CaseIterable {
    case wordOnly = "단어 추가"
    case mapping = "매핑 추가"

    var description: String {
        switch self {
        case .wordOnly: return "STT + LLM 사전에 단어 추가"
        case .mapping: return "LLM 교정 매핑 추가 (STT 미적용)"
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
                    .foregroundStyle(.blue)
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
            HStack(alignment: .top) {
                Text("선택된 텍스트:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
                Text(originalText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                Spacer()
            }

            // Correction input
            HStack {
                Text(mode == .mapping ? "교정할 단어:" : "추가할 단어:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
                TextField("올바른 단어를 입력하세요", text: $correctedText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        confirmIfValid()
                    }
            }

            if mode == .mapping {
                HStack(alignment: .top) {
                    Text("")
                        .frame(width: 90)
                    Label("\"\(originalText)\" → \"\(correctedText.isEmpty ? "..." : correctedText)\"", systemImage: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
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
