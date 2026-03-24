import SwiftUI

struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                // STT Models Section
                SettingsCard(title: "STT 모델", description: "음성 인식 모델") {
                    VStack(spacing: DesignTokens.Spacing.md) {
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

                // LLM Models Section
                SettingsCard(title: "LLM 모델", description: "텍스트 교정 모델") {
                    ModelRow(
                        name: "Qwen3 4B Instruct (4-bit)",
                        description: "한국어/영어 텍스트 교정",
                        size: "~2.0 GB",
                        state: modelManager.localLLMDownloaded ? .ready : activeLLMState,
                        downloadProgress: appState.llmDownloadProgress,
                        onDownload: {
                            Task { await modelManager.downloadLocalLLMModel() }
                        },
                        onDelete: { modelManager.deleteLLMModel() }
                    )
                }

                // Storage Section
                SettingsCard(title: "저장 공간") {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        SettingsRow(label: "모델 위치") {
                            Text("~/Library/Application Support/")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                        Button("Finder에서 열기") {
                            NSWorkspace.shared.open(ModelManager.modelsDirectory)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.surfaceBackground)
        .onAppear {
            modelManager.refreshCachedModelStates()
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
        if modelManager.isLocalLLMDownloading { return .loading }
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(.body, design: .default, weight: .medium))
                        .foregroundStyle(DesignTokens.textPrimary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                Spacer()
                Text(size)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
            }

            switch state {
            case .notDownloaded:
                Button("다운로드") { onDownload() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            case .downloading(let progress):
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress)
                        .tint(DesignTokens.accentPrimary)
                    Text("\(Int(progress * 100))% 다운로드 중...")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            case .loading:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DesignTokens.accentPrimary)
                    Text("로딩 중...")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            case .ready:
                HStack(spacing: DesignTokens.Spacing.sm) {
                    StatusBadge("준비됨", icon: "checkmark.circle.fill", style: .success)
                    Spacer()
                    Button("삭제", role: .destructive) { onDelete() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            case .error(let msg):
                HStack(spacing: DesignTokens.Spacing.sm) {
                    StatusBadge(msg, icon: "exclamationmark.triangle.fill", style: .error)
                        .lineLimit(2)
                    Spacer()
                    Button("재시도") { onDownload() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }
}
