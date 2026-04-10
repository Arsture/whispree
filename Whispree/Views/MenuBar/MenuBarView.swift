import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.accentPrimary)
                Text("Whispree")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            .padding(.bottom, 2)

            sectionCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)

                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(appState.transcriptionState.displayText)
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }

                    if appState.isRecording {
                        AudioLevelBar(level: appState.currentAudioLevel)
                            .frame(height: 4)
                    }
                }
            }

            // Recent transcription
            if !appState.finalText.isEmpty {
                sectionCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last transcription")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)

                        Text(appState.correctedText.isEmpty ? appState.finalText : appState.correctedText)
                            .font(.body)
                            .foregroundStyle(DesignTokens.textPrimary)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }
            }

            sectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Controls")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)

                    Toggle("LLM Correction", isOn: Binding(
                        get: { appState.settings.isLLMEnabled },
                        set: { appState.settings.isLLMEnabled = $0 }
                    ))
                    .toggleStyle(.switch)
                    .font(.subheadline)

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
                }
            }

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

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(DesignTokens.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignTokens.Surface.cardTint)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DesignTokens.Border.subtle, lineWidth: 1)
                }
        )
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
        DesignTokens.accentPrimary.opacity(0.45 + min(CGFloat(level), 1) * 0.45)
    }
}
