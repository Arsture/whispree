import SwiftUI

struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        Form {
            Section("Speech-to-Text Model") {
                ModelRow(
                    name: "Whisper Large V3 Turbo",
                    description: "Fast, accurate STT for 99 languages",
                    size: "~1.5 GB",
                    state: appState.whisperModelState,
                    downloadProgress: appState.whisperDownloadProgress,
                    onDownload: { Task { try? await modelManager.downloadWhisperModel() } },
                    onDelete: { modelManager.deleteWhisperModel() }
                )
            }

            Section("Text Correction Model") {
                ModelRow(
                    name: "Qwen3 4B Instruct (4-bit)",
                    description: "Korean/English text correction",
                    size: "~2.0 GB",
                    state: appState.llmModelState,
                    downloadProgress: appState.llmDownloadProgress,
                    onDownload: { Task { try? await modelManager.downloadLLMModel() } },
                    onDelete: { modelManager.deleteLLMModel() }
                )
            }

            Section("Storage") {
                HStack {
                    Text("Models location:")
                    Spacer()
                    Text("~/Library/Application Support/NotMyWhisper/Models")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Open in Finder") {
                    NSWorkspace.shared.open(ModelManager.modelsDirectory)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ModelRow: View {
    let name: String
    let description: String
    let size: String
    let state: ModelState
    let downloadProgress: Double
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(size)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            switch state {
            case .notDownloaded:
                Button("Download") { onDownload() }
                    .buttonStyle(.borderedProminent)
            case .downloading(let progress):
                ProgressView(value: progress)
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .loading:
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption)
                }
            case .ready:
                HStack {
                    Label("Ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Spacer()
                    Button("Delete", role: .destructive) { onDelete() }
                        .font(.caption)
                }
            case .error(let msg):
                HStack {
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Spacer()
                    Button("Retry") { onDownload() }
                        .font(.caption)
                }
            }
        }
    }
}
