import SwiftUI
import KeyboardShortcuts

struct MainDashboardView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var modelManager: ModelManager
    let onOpenSettings: () -> Void
    @State private var modelDownloadError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(16)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Recording status + waveform
                    recordingSection

                    // Last transcription
                    if !appState.finalText.isEmpty {
                        transcriptionSection
                    }

                    // Model status
                    modelStatusSection

                    // Hotkey
                    hotkeySection

                    // Quick settings
                    quickSettingsSection
                }
                .padding(16)
            }

            Divider()

            // Footer
            HStack {
                Button("Settings") {
                    onOpenSettings()
                }

                Spacer()

                Button("Quit FreeWhisper") {
                    NSApp.terminate(nil)
                }
                .foregroundStyle(.red)
            }
            .padding(12)
        }
        .frame(minWidth: 420, minHeight: 480)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("FreeWhisper")
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

    // MARK: - Transcription

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last Transcription")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
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

            // Always show raw STT result
            VStack(alignment: .leading, spacing: 2) {
                Text("STT Result")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(appState.finalText)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(4)
            }

            // Show LLM corrected if available
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Model Status

    private var modelStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            modelRow(
                icon: "mic.fill",
                name: "Whisper STT",
                state: modelManager.whisperModelInfo.state,
                onDownload: {
                    Task {
                        do {
                            try await modelManager.downloadWhisperModel()
                        } catch {
                            modelDownloadError = error.localizedDescription
                        }
                    }
                },
                onDelete: { modelManager.deleteWhisperModel() }
            )

            modelRow(
                icon: "text.badge.checkmark",
                name: "Qwen LLM",
                state: modelManager.llmModelInfo.state,
                onDownload: {
                    Task {
                        do {
                            try await modelManager.downloadLLMModel()
                        } catch {
                            modelDownloadError = error.localizedDescription
                        }
                    }
                },
                onDelete: { modelManager.deleteLLMModel() }
            )

            if let modelDownloadError {
                Text(modelDownloadError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }

    private func modelRow(icon: String, name: String, state: ModelState, onDownload: @escaping () -> Void, onDelete: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
            Text(name)
                .font(.subheadline)
            Spacer()

            switch state {
            case .ready:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .notDownloaded, .error:
                Button("Download", action: onDownload)
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            case .downloading(let progress):
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


    // MARK: - Hotkey

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hotkey")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack {
                Text("Recording shortcut:")
                    .font(.subheadline)
                Spacer()
                KeyboardShortcuts.Recorder(for: .toggleRecording)
            }

            Text("Mode: \(appState.settings.recordingMode.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }

    // MARK: - Quick Settings

    private var quickSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Settings")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Toggle("LLM Correction", isOn: Binding(
                get: { appState.settings.isLLMEnabled },
                set: {
                    appState.settings.isLLMEnabled = $0
                    appState.settings.save()
                }
            ))
            .font(.subheadline)

            Picker("Language:", selection: Binding(
                get: { appState.settings.language },
                set: {
                    appState.settings.language = $0
                    appState.settings.save()
                }
            )) {
                ForEach(SupportedLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .font(.subheadline)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary.opacity(0.5))
        )
    }
}
