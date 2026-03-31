import SwiftUI

struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // STT Models Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("STT 모델")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        ModelRow(
                            name: "WhisperKit Large V3 Turbo",
                            description: "로컬 CoreML+ANE, 99개 언어",
                            size: "~1.5 GB",
                            state: modelManager.whisperKitDownloaded ? .ready : activeWhisperKitState,
                            downloadProgress: appState.whisperDownloadProgress,
                            onDownload: {
                                Task { await modelManager.downloadWhisperKitModel() }
                            },
                            onDelete: { modelManager.deleteWhisperModel() }
                        )

                        ModelRow(
                            name: "Qwen3-ASR-1.7B-8bit",
                            description: "mlx-audio, 한중일영 (uv 필요)",
                            size: "~1.0 GB",
                            state: modelManager.mlxAudioDownloaded ? .ready : modelManager.mlxAudioDownloadState,
                            downloadProgress: 0,
                            onDownload: {
                                Task { await modelManager.downloadMLXAudioModel() }
                            },
                            onDelete: { modelManager.deleteMLXAudioModel() }
                        )
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary.opacity(0.5))
                )

                // LLM Models Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("LLM 모델")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    VStack(spacing: 12) {
                        ForEach(LocalModelSpec.supported) { spec in
                            let isCached = modelManager.modelCacheStates[spec.id] ?? false
                            let isDownloading = modelManager.downloadingModelIds.contains(spec.id)
                            let isSelected = appState.settings.llmModelId == spec.id
                            let errorMsg = modelManager.modelErrors[spec.id]

                            let state: ModelState = {
                                if isCached { return .ready }
                                if isDownloading { return .loading }
                                if let err = errorMsg { return .error(err) }
                                return .notDownloaded
                            }()

                            ModelRow(
                                name: spec.displayName + (spec.capability == .vision ? " 👁" : "") + (isSelected ? " ✦" : ""),
                                description: spec.description,
                                size: spec.sizeDescription,
                                state: state,
                                downloadProgress: 0,
                                onDownload: {
                                    Task { await modelManager.downloadLLMModel(modelId: spec.id) }
                                },
                                onDelete: { modelManager.deleteLLMModel(modelId: spec.id) }
                            )
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary.opacity(0.5))
                )

                // Storage Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("저장 공간")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

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
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary.opacity(0.5))
                )
            }
            .padding(24)
        }
        .onAppear {
            modelManager.refreshAllCacheStates()
        }
    }

    /// 현재 WhisperKit provider가 활성 상태이고 다운로드 중이면 그 상태 반영
    private var activeWhisperKitState: ModelState {
        if appState.settings.sttProviderType == .whisperKit {
            if case .downloading = appState.whisperModelState { return appState.whisperModelState }
            if case .loading = appState.whisperModelState { return appState.whisperModelState }
        }
        if modelManager.isWhisperKitDownloading { return .loading }
        return .notDownloaded
    }

    private var activeLLMState: ModelState {
        if appState.settings.llmProviderType == .local {
            if case .downloading = appState.llmModelState { return appState.llmModelState }
            if case .loading = appState.llmModelState { return appState.llmModelState }
        }
        if !modelManager.downloadingModelIds.isEmpty { return .loading }
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
                case let .downloading(progress):
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
                case let .error(msg):
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
