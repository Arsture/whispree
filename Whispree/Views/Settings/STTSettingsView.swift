import SwiftUI

struct STTSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // STT Provider
                LiquidSection("음성 인식 엔진") {
                    VStack(spacing: 0) {
                        STTProviderRow(
                            title: "Groq Cloud API",
                            description: "클라우드 STT, API Key 필요",
                            metrics: .cloud(latencyMs: 200, qualityScore: 95),
                            isSelected: appState.settings.sttProviderType == .groq,
                            state: appState.settings.sttProviderType == .groq ? appState.whisperModelState : .ready,
                            onSelect: {
                                appState.settings.sttProviderType = .groq
                                Task { await appState.switchSTTProvider(to: .groq) }
                            }
                        )

                        Divider()

                        let mlxCompat = ModelCompatibility.evaluate(modelSizeBytes: 1_000_000_000)
                        STTProviderRow(
                            title: "MLX Audio",
                            description: "mlx-audio, 한중일영 (uv 필요)",
                            metrics: .local(size: "~1.0 GB", ramPercent: mlxCompat.ramUsagePercent, tokPerSec: nil, qualityScore: 65, grade: mlxCompat.grade),
                            isSelected: appState.settings.sttProviderType == .mlxAudio,
                            state: appState.settings.sttProviderType == .mlxAudio ? appState.whisperModelState : (modelManager.mlxAudioDownloaded ? .ready : .notDownloaded),
                            onSelect: {
                                appState.settings.sttProviderType = .mlxAudio
                                Task { await appState.switchSTTProvider(to: .mlxAudio) }
                            }
                        )

                        Divider()

                        let whisperCompat = ModelCompatibility.evaluate(modelSizeBytes: 1_500_000_000)
                        STTProviderRow(
                            title: "WhisperKit",
                            description: "로컬 CoreML+ANE, 99개 언어",
                            metrics: .local(size: "~1.5 GB", ramPercent: whisperCompat.ramUsagePercent, tokPerSec: nil, qualityScore: 75, grade: whisperCompat.grade),
                            isSelected: appState.settings.sttProviderType == .whisperKit,
                            state: appState.settings.sttProviderType == .whisperKit ? appState.whisperModelState : (modelManager.whisperKitDownloaded ? .ready : .notDownloaded),
                            onSelect: {
                                appState.settings.sttProviderType = .whisperKit
                                Task { await appState.switchSTTProvider(to: .whisperKit) }
                            }
                        )
                    }
                }

                // Groq API Key
                if appState.settings.sttProviderType == .groq {
                    LiquidSection("API Key") {
                        VStack(alignment: .leading, spacing: 10) {
                            SecureField("API Key", text: Binding(
                                get: { appState.settings.groqApiKey },
                                set: { appState.settings.groqApiKey = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)

                            if appState.settings.groqApiKey.isEmpty {
                                Label("console.groq.com에서 무료 API Key를 발급받으세요", systemImage: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
                            } else {
                                Label("API Key 설정됨", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Cold Start
                if case .loading = appState.whisperModelState,
                   appState.settings.sttProviderType == .mlxAudio
                {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("콜드 스타트 중...")
                                .font(.caption).fontWeight(.medium)
                            Text("첫 실행 시 약 1분 소요됩니다.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(DesignTokens.surfaceBackgroundView(role: .card))
                }

                // Download Notice
                if case .notDownloaded = appState.whisperModelState,
                   appState.settings.sttProviderType != .groq
                {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(DesignTokens.accentPrimary)
                        Text("다운로드 탭에서 모델을 다운로드하세요.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(DesignTokens.surfaceBackgroundView(role: .card))
                }

                // VAD
                LiquidSection("무음 자동 스킵") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("활성화")
                                    .font(.subheadline.weight(.medium))
                                Text("끄면 pause 인디케이터와 무음 후처리를 함께 비활성화합니다.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { appState.settings.vadEnabled },
                                set: {
                                    appState.settings.vadEnabled = $0
                                    if !$0 { appState.isThinkingPause = false }
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }

                        Label(
                            appState.settings.vadEnabled
                                ? "현재 ON — 긴 무음만 잘라서 전사하고, 녹음 중 pause 인디케이터를 표시합니다."
                                : "현재 OFF — 무음 포함 전체 오디오를 전사하고, pause 인디케이터도 표시하지 않습니다.",
                            systemImage: appState.settings.vadEnabled ? "waveform.badge.minus" : "waveform"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            appState.settings.vadEnabled
                                ? DesignTokens.semanticColors(for: .warning).foreground
                                : .secondary
                        )
                    }
                }
            }
            .padding(24)
        }
        .liquidBackground()
    }
}

// MARK: - STTProviderRow (no nested background)

struct STTProviderRow: View {
    let title: String
    let description: String
    let metrics: ModelMetrics
    let isSelected: Bool
    let state: ModelState
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? DesignTokens.accentPrimary : DesignTokens.textTertiary)
                        .font(.body)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.medium))
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    metricsView
                }

                if isSelected {
                    providerStateView
                        .padding(.leading, 28)
                }
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var providerStateView: some View {
        switch state {
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.secondary)
        case .queued, .loading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Loading...").font(.caption).foregroundStyle(.secondary)
            }
        case .downloading:
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("Downloading...").font(.caption).foregroundStyle(.secondary)
            }
        case .notDownloaded:
            Label("다운로드 필요", systemImage: "arrow.down.circle")
                .font(.caption)
                .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
        case let .error(msg):
            Label(msg, systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
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
