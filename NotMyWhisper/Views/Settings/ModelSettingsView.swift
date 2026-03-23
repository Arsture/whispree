import SwiftUI

struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        Form {
            Section("STT 모델") {
                ModelRow(
                    name: "WhisperKit Large V3 Turbo",
                    description: "로컬 CoreML+ANE, 99개 언어",
                    size: "~1.5 GB",
                    state: appState.whisperModelState,
                    downloadProgress: appState.whisperDownloadProgress,
                    onDownload: {
                        Task {
                            try? await modelManager.downloadWhisperModel()
                            await appState.switchSTTProvider(to: .whisperKit)
                        }
                    },
                    onDelete: { modelManager.deleteWhisperModel() }
                )

                ModelRow(
                    name: "Qwen3-ASR-1.7B-8bit",
                    description: "mlx-audio, 한중일영 (uv 필요)",
                    size: "~1.0 GB",
                    state: mlxAudioModelState,
                    downloadProgress: 0,
                    onDownload: {
                        Task { await appState.switchSTTProvider(to: .mlxAudio) }
                    },
                    onDelete: { }
                )
            }

            Section("LLM 모델") {
                ModelRow(
                    name: "Qwen3 4B Instruct (4-bit)",
                    description: "한국어/영어 텍스트 교정",
                    size: "~2.0 GB",
                    state: appState.llmModelState,
                    downloadProgress: appState.llmDownloadProgress,
                    onDownload: { Task { try? await modelManager.downloadLLMModel() } },
                    onDelete: { modelManager.deleteLLMModel() }
                )
            }

            Section("저장 공간") {
                HStack {
                    Text("모델 위치:")
                    Spacer()
                    Text("~/Library/Application Support/")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Finder에서 열기") {
                    NSWorkspace.shared.open(ModelManager.modelsDirectory)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var mlxAudioModelState: ModelState {
        if appState.settings.sttProviderType == .mlxAudio {
            return appState.whisperModelState
        }
        return .notDownloaded
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
                Button("다운로드") { onDownload() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            case .downloading(let progress):
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                    Text("\(Int(progress * 100))% 다운로드 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .loading:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("로딩 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .ready:
                HStack {
                    Label("준비됨", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Spacer()
                    Button("삭제", role: .destructive) { onDelete() }
                        .font(.caption)
                        .controlSize(.small)
                }
            case .error(let msg):
                HStack {
                    Label(msg, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    Button("재시도") { onDownload() }
                        .font(.caption)
                        .controlSize(.small)
                }
            }
        }
    }
}
