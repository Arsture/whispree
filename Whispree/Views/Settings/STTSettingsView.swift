import SwiftUI

struct STTSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.md) {
                // Provider Cards
                SettingsCard(title: "STT Provider", description: "음성 인식 엔진") {
                    VStack(spacing: DesignTokens.Spacing.xs) {
                        ProviderCard(
                            provider: .groq,
                            title: "Groq Cloud API",
                            accuracy: 95,
                            latency: 95,
                            networkType: .network,
                            isSelected: appState.settings.sttProviderType == .groq,
                            state: appState.whisperModelState,
                            onSelect: {
                                appState.settings.sttProviderType = .groq
                                appState.settings.save()
                                Task { await appState.switchSTTProvider(to: .groq) }
                            }
                        )

                        ProviderCard(
                            provider: .mlxAudio,
                            title: "MLX Audio",
                            accuracy: 65,
                            latency: 65,
                            networkType: .offline,
                            isSelected: appState.settings.sttProviderType == .mlxAudio,
                            state: appState.whisperModelState,
                            onSelect: {
                                appState.settings.sttProviderType = .mlxAudio
                                appState.settings.save()
                                Task { await appState.switchSTTProvider(to: .mlxAudio) }
                            }
                        )

                        ProviderCard(
                            provider: .whisperKit,
                            title: "WhisperKit",
                            accuracy: 75,
                            latency: 55,
                            networkType: .offline,
                            isSelected: appState.settings.sttProviderType == .whisperKit,
                            state: appState.whisperModelState,
                            onSelect: {
                                appState.settings.sttProviderType = .whisperKit
                                appState.settings.save()
                                Task { await appState.switchSTTProvider(to: .whisperKit) }
                            }
                        )
                    }
                }

                // Groq API Key Section
                if appState.settings.sttProviderType == .groq {
                    SettingsCard(title: "Groq API Key") {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            SecureField("API Key", text: Binding(
                                get: { appState.settings.groqApiKey },
                                set: {
                                    appState.settings.groqApiKey = $0
                                    appState.settings.save()
                                }
                            ))
                            .textFieldStyle(.roundedBorder)

                            if appState.settings.groqApiKey.isEmpty {
                                StatusBadge("console.groq.com에서 무료 API Key를 발급받으세요", icon: "info.circle", style: .warning)
                            } else {
                                StatusBadge("API Key 설정됨", icon: "checkmark.circle.fill", style: .success)
                            }
                        }
                    }
                }

                // Cold Start Warning
                if case .loading = appState.whisperModelState,
                   appState.settings.sttProviderType == .mlxAudio {
                    SettingsCard {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(DesignTokens.statusInfo)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("콜드 스타트 중...")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DesignTokens.textPrimary)
                                Text("첫 실행 시 약 1분 소요됩니다. 이후엔 즉시 사용 가능합니다.")
                                    .font(.caption2)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                    }
                }

                // Model Download Notice
                if case .notDownloaded = appState.whisperModelState,
                   appState.settings.sttProviderType != .groq {
                    SettingsCard {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(DesignTokens.statusWarning)
                            Text("모델 탭에서 모델을 다운로드하세요.")
                                .font(.caption)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}

enum NetworkType {
    case offline
    case network
}

struct ProviderCard: View {
    let provider: STTProviderType
    let title: String
    let accuracy: Int  // 0-100
    let latency: Int   // 0-100
    let networkType: NetworkType
    let isSelected: Bool
    let state: ModelState
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Radio button
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DesignTokens.accentPrimary : DesignTokens.textSecondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    // Title
                    Text(title)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(DesignTokens.textPrimary)

                    // Metrics
                    HStack(spacing: DesignTokens.Spacing.lg) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accuracy")
                                .font(.caption2)
                                .foregroundStyle(DesignTokens.textSecondary)
                            MetricBar(value: accuracy)
                        }
                        .frame(width: 100)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speed")
                                .font(.caption2)
                                .foregroundStyle(DesignTokens.textSecondary)
                            MetricBar(value: latency)
                        }
                        .frame(width: 100)

                        // Network badge
                        HStack(spacing: 4) {
                            Image(systemName: networkType == .offline ? "lock.fill" : "network")
                                .font(.caption2)
                            Text(networkType == .offline ? "Local" : "Cloud")
                                .font(.caption2)
                        }
                        .foregroundStyle(DesignTokens.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DesignTokens.textSecondary.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    // State indicator
                    if isSelected {
                        HStack(spacing: 6) {
                            switch state {
                            case .ready:
                                StatusBadge("Ready", icon: "checkmark.circle.fill", style: .success)
                            case .loading:
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(DesignTokens.accentPrimary)
                                    Text(provider == .mlxAudio ? "Cold start..." : "Loading...")
                                        .font(.caption)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                            case .downloading:
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(DesignTokens.accentPrimary)
                                    Text("Downloading...")
                                        .font(.caption)
                                        .foregroundStyle(DesignTokens.textSecondary)
                                }
                            case .notDownloaded:
                                StatusBadge("Download required", icon: "arrow.down.circle", style: .warning)
                            case .error(let msg):
                                StatusBadge(msg, icon: "xmark.circle", style: .error)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(DesignTokens.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .strokeBorder(isSelected ? DesignTokens.accentPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct MetricBar: View {
    let value: Int  // 0-100

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.textSecondary.opacity(0.15))

                RoundedRectangle(cornerRadius: 2)
                    .fill(DesignTokens.accentPrimary)
                    .frame(width: geo.size.width * CGFloat(value) / 100)
            }
        }
        .frame(height: 4)
    }
}
