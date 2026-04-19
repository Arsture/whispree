import SwiftUI

struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    private let device = DeviceCapability.current

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Device Info — inline pills
                HStack(spacing: 10) {
                    modelInfoPill(device.chipName, systemImage: "cpu")
                    modelInfoPill("\(device.totalRAMGB) GB", systemImage: "memorychip")
                    modelInfoPill("~\(device.memoryBandwidthGBs) GB/s", systemImage: "arrow.left.arrow.right")
                    modelInfoPill("\(device.gpuCores) cores", systemImage: "gpu")
                }

                // STT Models
                LiquidSection("STT 모델") {
                    VStack(spacing: 0) {
                        let whisperCompat = ModelCompatibility.evaluate(modelSizeBytes: 1_500_000_000)
                        DownloadableModelRow(
                            name: "WhisperKit Large V3 Turbo",
                            description: "로컬 CoreML+ANE, 99개 언어",
                            metrics: .local(size: "~1.5 GB", ramPercent: whisperCompat.ramUsagePercent, tokPerSec: nil, qualityScore: 75, grade: whisperCompat.grade),
                            state: modelManager.whisperKitDownloaded ? .ready : activeWhisperKitState,
                            onDownload: { Task { await modelManager.downloadWhisperKitModel() } },
                            onDelete: { modelManager.deleteWhisperModel() }
                        )

                        Divider()

                        let mlxCompat = ModelCompatibility.evaluate(modelSizeBytes: 1_000_000_000)
                        DownloadableModelRow(
                            name: "Qwen3-ASR-1.7B-8bit",
                            description: "mlx-audio, 한중일영 (uv 필요)",
                            metrics: .local(size: "~1.0 GB", ramPercent: mlxCompat.ramUsagePercent, tokPerSec: nil, qualityScore: 65, grade: mlxCompat.grade),
                            state: modelManager.mlxAudioDownloaded ? .ready : modelManager.mlxAudioDownloadState,
                            onDownload: { Task { await modelManager.downloadMLXAudioModel() } },
                            onDelete: { modelManager.deleteMLXAudioModel() }
                        )
                    }
                }

                // LLM Models
                LiquidSection("LLM 모델") {
                    let sttOverhead: Int64 = {
                        switch appState.settings.sttProviderType {
                        case .whisperKit: return 1_500_000_000
                        case .mlxAudio: return 1_000_000_000
                        case .groq: return 0
                        }
                    }()

                    VStack(spacing: 0) {
                        ForEach(Array(LocalModelSpec.supported.enumerated()), id: \.element.id) { index, spec in
                            if index > 0 { Divider() }

                            let isCached = modelManager.modelCacheStates[spec.id] ?? false
                            let isDownloading = modelManager.downloadingModelIds.contains(spec.id)
                            let isSelected = appState.settings.llmModelId == spec.id
                            let errorMsg = modelManager.modelErrors[spec.id]
                            let compat = spec.compatibility(otherModelSizeBytes: sttOverhead)

                            let state: ModelState = {
                                if isCached { return .ready }
                                if isDownloading { return .loading }
                                if let err = errorMsg { return .error(err) }
                                return .notDownloaded
                            }()

                            DownloadableModelRow(
                                name: spec.displayName,
                                description: spec.description,
                                metrics: .local(
                                    size: spec.sizeDescription,
                                    ramPercent: compat.ramUsagePercent,
                                    tokPerSec: compat.estimatedTokPerSec,
                                    qualityScore: spec.qualityScore,
                                    grade: compat.grade
                                ),
                                state: state,
                                isSelected: isSelected,
                                supportsVision: spec.capability == .vision,
                                onDownload: { Task { await modelManager.downloadLLMModel(modelId: spec.id) } },
                                onDelete: { modelManager.deleteLLMModel(modelId: spec.id) }
                            )
                        }
                    }
                }

                // Storage
                LiquidSection("저장 공간") {
                    VStack(alignment: .leading, spacing: 8) {
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
                        .font(.caption)
                    }
                }
            }
            .padding(24)
        }
        .liquidBackground()
        .task {
            await modelManager.refreshAllCacheStatesAsync()
        }
    }

    private var activeWhisperKitState: ModelState {
        if appState.settings.sttProviderType == .whisperKit {
            if case .downloading = appState.whisperModelState { return appState.whisperModelState }
            if case .loading = appState.whisperModelState { return appState.whisperModelState }
        }
        if modelManager.isWhisperKitDownloading { return .loading }
        return .notDownloaded
    }

    @ViewBuilder
    private func modelInfoPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }
}

// MARK: - ModelMetrics

enum ModelMetrics {
    case local(size: String, ramPercent: Int, tokPerSec: Int?, qualityScore: Int, grade: CompatibilityGrade)
    case cloud(latencyMs: Int, qualityScore: Int)
}

// MARK: - DownloadableModelRow (no nested background)

struct DownloadableModelRow: View {
    let name: String
    let description: String
    let metrics: ModelMetrics
    let state: ModelState
    var isSelected: Bool = false
    var supportsVision: Bool = false
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(name)
                            .font(.subheadline.weight(.medium))

                        if supportsVision {
                            Text("Vision")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(DesignTokens.accentPrimary)
                        }

                        if isSelected {
                            Text("사용 중")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                metricsView
            }

            stateControls
        }
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var stateControls: some View {
        switch state {
        case .notDownloaded:
            Button("다운로드") { onDownload() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        case let .downloading(progress):
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                Text("\(Int(progress * 100))% 다운로드 중...")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("로딩 중...").font(.caption).foregroundStyle(.secondary)
            }
        case .ready:
            HStack {
                Label("준비됨", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("삭제", role: .destructive) { onDelete() }
                    .font(.caption).controlSize(.small)
            }
        case let .error(msg):
            HStack {
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                    .font(.caption).lineLimit(2)
                Spacer()
                Button("재시도") { onDownload() }
                    .font(.caption).controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var metricsView: some View {
        switch metrics {
        case let .local(size, ramPercent, tokPerSec, qualityScore, grade):
            ModelMetricsView(
                sizeText: size, ramPercent: ramPercent,
                tokPerSec: tokPerSec, latencyMs: nil,
                qualityScore: qualityScore, grade: grade
            )
        case let .cloud(latencyMs, qualityScore):
            ModelMetricsView(
                sizeText: "☁️", ramPercent: nil,
                tokPerSec: nil, latencyMs: latencyMs,
                qualityScore: qualityScore, grade: .runsGreat
            )
        }
    }
}
