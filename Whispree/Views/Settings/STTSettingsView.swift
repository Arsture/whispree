import SwiftUI

struct STTSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("STT Provider")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                VStack(spacing: 8) {
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
                        accuracy: 75,
                        latency: 80,
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
                        accuracy: 70,
                        latency: 50,
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
                .padding(.horizontal)

                // Groq API Key Section
                if appState.settings.sttProviderType == .groq {
                    Divider()
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Groq API Key")
                            .font(.headline)

                        SecureField("API Key", text: Binding(
                            get: { appState.settings.groqApiKey },
                            set: {
                                appState.settings.groqApiKey = $0
                                appState.settings.save()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)

                        if appState.settings.groqApiKey.isEmpty {
                            Label("console.groq.com에서 무료 API Key를 발급받으세요", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Label("API Key 설정됨", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal)
                }

                // Cold Start Warning
                if case .loading = appState.whisperModelState,
                   appState.settings.sttProviderType == .mlxAudio {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("콜드 스타트 중...")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("첫 실행 시 약 1분 소요됩니다. 이후엔 즉시 사용 가능합니다.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                // Model Download Notice
                if case .notDownloaded = appState.whisperModelState,
                   appState.settings.sttProviderType != .groq {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(.orange)
                        Text("모델 탭에서 모델을 다운로드하세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
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
            HStack(spacing: 16) {
                // Radio button
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 10) {
                    // Title
                    Text(title)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.primary)

                    // Metrics
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Accuracy")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            MetricBar(value: accuracy)
                        }
                        .frame(width: 100)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Speed")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                    }

                    // State indicator
                    if isSelected {
                        HStack(spacing: 6) {
                            switch state {
                            case .ready:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Ready")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .loading:
                                ProgressView()
                                    .controlSize(.small)
                                Text(provider == .mlxAudio ? "Cold start..." : "Loading...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .downloading:
                                ProgressView()
                                    .controlSize(.small)
                                Text("Downloading...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .notDownloaded:
                                Image(systemName: "arrow.down.circle")
                                    .foregroundStyle(.orange)
                                Text("Download required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .error(let msg):
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.red)
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
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
                    .fill(Color.secondary.opacity(0.15))

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * CGFloat(value) / 100)
            }
        }
        .frame(height: 4)
    }
}
