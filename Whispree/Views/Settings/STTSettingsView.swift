import SwiftUI

struct STTSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var modelManager: ModelManager

    var body: some View {
        Form {
            Section("STT Provider") {
                Picker("Provider", selection: Binding(
                    get: { appState.settings.sttProviderType },
                    set: { (newValue: STTProviderType) in
                        appState.settings.sttProviderType = newValue
                        appState.settings.save()
                        Task { await appState.switchSTTProvider(to: newValue) }
                    }
                )) {
                    ForEach(STTProviderType.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }

                HStack {
                    Text("상태:")
                    Spacer()
                    switch appState.whisperModelState {
                    case .ready:
                        Label("준비됨", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    case .notDownloaded:
                        Label("모델 필요", systemImage: "arrow.down.circle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    case .loading:
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text(loadingStatusText)
                                .font(.caption)
                        }
                    case .downloading:
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.small)
                            Text("다운로드 중...")
                                .font(.caption)
                        }
                    case .error(let msg):
                        Label(msg, systemImage: "xmark.circle")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }

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
                    .padding(8)
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            if appState.settings.sttProviderType == .groq {
                Section("Groq API") {
                    SecureField("Groq API Key", text: Binding(
                        get: { appState.settings.groqApiKey },
                        set: {
                            appState.settings.groqApiKey = $0
                            appState.settings.save()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)

                    if appState.settings.groqApiKey.isEmpty {
                        Label("console.groq.com에서 API Key를 발급받으세요", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Label("API Key 설정됨", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            if case .notDownloaded = appState.whisperModelState,
               appState.settings.sttProviderType != .groq {
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("모델 탭에서 모델을 다운로드하세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var loadingStatusText: String {
        if appState.settings.sttProviderType == .mlxAudio {
            return "콜드 스타트 중... (약 1분)"
        }
        return "로딩 중..."
    }
}
