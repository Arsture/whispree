import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                Text("Whispree")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            .padding(.bottom, 4)

            Divider()

            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.transcriptionState.displayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Audio level during recording
            if appState.isRecording {
                AudioLevelBar(level: appState.currentAudioLevel)
                    .frame(height: 4)
            }

            // Recent transcription
            if !appState.finalText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last transcription")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(appState.correctedText.isEmpty ? appState.finalText : appState.correctedText)
                        .font(.body)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                .padding(8)
                .background(DesignTokens.Surface.subdued)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()

            // Quick toggles
            Toggle("LLM Correction", isOn: Binding(
                get: { appState.settings.isLLMEnabled },
                set: { appState.settings.isLLMEnabled = $0 }
            ))
            .toggleStyle(.switch)
            .font(.subheadline)

            // Recording mode
            Picker("Mode", selection: Binding(
                get: { appState.settings.recordingMode },
                set: { appState.settings.recordingMode = $0 }
            )) {
                ForEach(RecordingMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .font(.subheadline)

            Divider()

            // Actions
            HStack {
                Button("Settings...") {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.showMainWindow()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.accentPrimary)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
            }
            .font(.subheadline)
        }
        .padding(16)
        .frame(width: 320)
    }

    private var statusBadge: some View {
        Group {
            if appState.whisperModelState.isReady {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
            }
        }
    }

    private var statusColor: Color {
        switch appState.transcriptionState {
            case .idle: DesignTokens.semanticColors(for: .success).foreground
            case .recording: DesignTokens.semanticColors(for: .danger).foreground
            case .transcribing, .correcting: DesignTokens.semanticColors(for: .warning).foreground
            case .inserting, .selectingScreenshots: DesignTokens.accentPrimary
        }
    }
}

struct AudioLevelBar: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.Surface.subdued)

                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor)
                    .frame(width: geo.size.width * CGFloat(level))
                    .animation(.linear(duration: 0.05), value: level)
            }
        }
    }

    private var barColor: Color {
        if level > 0.8 { return DesignTokens.semanticColors(for: .danger).foreground }
        if level > 0.5 { return DesignTokens.semanticColors(for: .warning).foreground }
        return DesignTokens.semanticColors(for: .success).foreground
    }
}
