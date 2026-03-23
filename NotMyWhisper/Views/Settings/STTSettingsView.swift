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

            if appState.settings.sttProviderType == .whisperKit {
                Section("WhisperKit 모델") {
                    ModelRow(
                        name: "Whisper Large V3 Turbo",
                        description: "Fast, accurate STT for 99 languages",
                        size: "~1.5 GB",
                        state: appState.whisperModelState,
                        downloadProgress: appState.whisperDownloadProgress,
                        onDownload: {
                            Task {
                                try? await modelManager.downloadWhisperModel()
                                await appState.switchSTTProvider(to: .whisperKit)
                            }
                        },
                        onDelete: {
                            modelManager.deleteWhisperModel()
                        }
                    )
                }

                if case .notDownloaded = appState.whisperModelState {
                    Section {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.blue)
                            Text("WhisperKit을 사용하려면 모델 다운로드가 필요합니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if appState.settings.sttProviderType == .mlxAudio {
                Section("MLX Audio") {
                    HStack {
                        Text("모델:")
                        Spacer()
                        Text(appState.settings.mlxAudioModelId.components(separatedBy: "/").last ?? "")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        Text("상태:")
                        Spacer()
                        switch appState.whisperModelState {
                        case .ready:
                            Label("준비됨", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        case .notDownloaded, .error:
                            Label("준비 안 됨", systemImage: "xmark.circle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        case .loading:
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.small)
                                Text("모델 로딩 중...")
                                    .font(.caption)
                            }
                        case .downloading:
                            HStack(spacing: 4) {
                                ProgressView().controlSize(.small)
                                Text("모델 다운로드 중...")
                                    .font(.caption)
                            }
                        }
                    }

                    Button("모델 로드") {
                        Task { await appState.switchSTTProvider(to: .mlxAudio) }
                    }
                    .disabled(appState.whisperModelState == .loading)
                }

                Section {
                    Label("uv와 Python 3.11+이 필요합니다. 첫 실행 시 모델 다운로드에 시간이 걸립니다.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .formStyle(.grouped)
        .padding()
    }
}
