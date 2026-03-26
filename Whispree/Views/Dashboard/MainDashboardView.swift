import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager
    @State private var modelDownloadError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(24)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Recording status + waveform
                    recordingSection

                    // Accessibility warning
                    if !TextInsertionService.isAccessibilityEnabled() {
                        accessibilityWarningSection
                    }

                    // Providers
                    providersSection
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Whispree")
                    .font(.title2.bold())
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusText: String {
        if appState.isRecording {
            return "Recording..."
        }
        if appState.transcriptionState == .transcribing {
            return "Transcribing..."
        }
        if appState.transcriptionState == .correcting {
            return "Correcting..."
        }
        if !modelManager.whisperModelInfo.state.isReady {
            return "Model not ready"
        }
        return "Ready - press hotkey to record"
    }

    private var statusColor: Color {
        if appState.isRecording { return .red }
        if appState.transcriptionState.isActive { return .orange }
        if modelManager.whisperModelInfo.state.isReady { return .green }
        return .secondary
    }

    private var statusBadge: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }

    // MARK: - Recording

    private var recordingSection: some View {
        VStack(spacing: 8) {
            if appState.isRecording {
                ScrollingWaveformView()
                    .frame(height: 56)
                    .padding(.horizontal, 4)

                Text("Listening... (ESC to cancel)")
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if appState.transcriptionState == .transcribing {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Transcribing your speech...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if appState.transcriptionState == .correcting {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Applying LLM correction...")
                    .font(.caption)
                    .foregroundStyle(.blue)
            } else {
                Image(systemName: "mic.circle")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary.opacity(0.5))
                Text("Press hotkey to start recording")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(appState.isRecording ? Color.red.opacity(0.08) : Color.secondary.opacity(0.05))
        )
    }

    // MARK: - Accessibility Warning

    private var accessibilityWarningSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility 권한 필요")
                    .font(.caption.bold())
                Text("텍스트 자동 삽입에 손쉬운 사용 권한이 필요합니다")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("허용") {
                TextInsertionService.requestAccessibilityPermission()
            }
            .font(.caption)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.yellow.opacity(0.1))
        )
    }

    // MARK: - Transcription

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last Transcription")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                if !appState.finalText.isEmpty {
                    Button {
                        let text = appState.correctedText.isEmpty ? appState.finalText : appState.correctedText
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                }
            }

            if appState.finalText.isEmpty {
                Text("아직 녹음 없음 — 핫키를 눌러 녹음을 시작하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                // Raw STT result
                VStack(alignment: .leading, spacing: 2) {
                    Text("STT Result")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(appState.finalText)
                        .font(.body)
                        .textSelection(.enabled)
                        .lineLimit(4)
                }

                // LLM corrected if available
                if !appState.correctedText.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LLM Corrected")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text(appState.correctedText)
                            .font(.body)
                            .textSelection(.enabled)
                            .lineLimit(4)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Provider Status

    private var providersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Providers")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            // STT Provider with picker
            HStack {
                Image(systemName: "mic.fill")
                    .frame(width: 20)
                Text("STT")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: sttProviderBinding) {
                    ForEach(STTProviderType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .frame(width: 180)
                providerStateBadge(appState.whisperModelState)
            }

            // Groq API key warning
            if appState.settings.sttProviderType == .groq, appState.settings.groqApiKey.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.yellow)
                        .font(.caption2)
                    Text("STT 설정에서 Groq API Key를 입력하세요")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 28)
            }

            Divider()

            // LLM Provider with picker
            HStack {
                Image(systemName: llmProviderIcon)
                    .frame(width: 20)
                Text("LLM")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: llmProviderBinding) {
                    ForEach(LLMProviderType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .frame(width: 180)
                if appState.settings.llmProviderType != .none {
                    providerStateBadge(appState.llmModelState)
                }
            }

            // OpenAI model info
            if appState.settings.llmProviderType == .openai {
                Text(appState.settings.openaiModel.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private var sttProviderBinding: Binding<STTProviderType> {
        Binding(
            get: { appState.settings.sttProviderType },
            set: { newType in
                appState.settings.sttProviderType = newType
                appState.settings.save()
                Task { await appState.switchSTTProvider(to: newType) }
            }
        )
    }

    private var llmProviderBinding: Binding<LLMProviderType> {
        Binding(
            get: { appState.settings.llmProviderType },
            set: { newType in
                appState.settings.llmProviderType = newType
                appState.settings.isLLMEnabled = (newType != .none)
                appState.settings.save()
                Task { await appState.switchLLMProvider(to: newType) }
            }
        )
    }

    private var llmProviderIcon: String {
        switch appState.settings.llmProviderType {
            case .none: "xmark.circle"
            case .local: "text.badge.checkmark"
            case .openai: "globe"
        }
    }

    @ViewBuilder
    private func providerStateBadge(_ state: ModelState) -> some View {
        switch state {
            case .ready:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .notDownloaded, .error:
                Label("Not Ready", systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            case let .downloading(progress):
                if progress > 0 {
                    HStack(spacing: 4) {
                        ProgressView(value: progress)
                            .frame(width: 50)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                    }
                } else {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.5)
                        Text("Downloading...")
                            .font(.caption2)
                    }
                }
            case .loading:
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.5)
                    Text("Loading...")
                        .font(.caption2)
                }
        }
    }
}
