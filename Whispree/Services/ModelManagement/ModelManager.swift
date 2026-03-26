import Combine
import Foundation

@MainActor
final class ModelManager: ObservableObject {
    @Published var whisperModelInfo = ModelInfo.whisperLargeV3Turbo
    @Published var llmModelInfo = ModelInfo.qwen3_4B
    @Published var isWhisperKitDownloading = false
    @Published var isMLXAudioDownloading = false
    @Published var isLocalLLMDownloading = false
    var isDownloading: Bool {
        isWhisperKitDownloading || isMLXAudioDownloading || isLocalLLMDownloading
    }

    // MARK: - 독립 모델 다운로드 상태 (Downloads 탭용, provider와 무관)

    @Published var whisperKitDownloaded: Bool = false
    @Published var mlxAudioDownloaded: Bool = false
    @Published var localLLMDownloaded: Bool = false
    @Published var mlxAudioDownloadState: ModelState = .notDownloaded

    private let appState: AppState
    private let sttService: STTService
    private let llmService: LLMService
    private var cancellables = Set<AnyCancellable>()

    static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whispree/Models", isDirectory: true)
    }

    init(appState: AppState, sttService: STTService, llmService: LLMService) {
        self.appState = appState
        self.sttService = sttService
        self.llmService = llmService
        createModelsDirectoryIfNeeded()
        observeProviderStates()
        refreshCachedModelStates()
    }

    private func observeProviderStates() {
        appState.$whisperModelState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.whisperModelInfo.state = state
            }
            .store(in: &cancellables)

        appState.$llmModelState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.llmModelInfo.state = state
            }
            .store(in: &cancellables)
    }

    private func createModelsDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: Self.modelsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - 디스크 캐시 기반 모델 상태 확인

    func refreshCachedModelStates() {
        // 이미 세션 중 다운로드 확인된 모델은 유지 (OR 로직)
        // 삭제 시에만 명시적으로 false 설정됨
        whisperKitDownloaded = whisperKitDownloaded || isModelCached(repoId: "argmaxinc/whisperkit-coreml")
        mlxAudioDownloaded = mlxAudioDownloaded || isModelCached(repoId: "mlx-community/Qwen3-ASR-1.7B-8bit")
        localLLMDownloaded = localLLMDownloaded || isModelCached(repoId: "mlx-community/Qwen3-4B-Instruct-2507-4bit")

        if mlxAudioDownloaded, mlxAudioDownloadState == .notDownloaded {
            mlxAudioDownloadState = .ready
        }
    }

    private func isModelCached(repoId: String) -> Bool {
        let fm = FileManager.default
        // HuggingFace 캐시: ~/.cache/huggingface/hub/models--{org}--{name}/
        let cacheDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let modelDir = cacheDir.appendingPathComponent("models--" + repoId.replacingOccurrences(of: "/", with: "--"))
        return fm.fileExists(atPath: modelDir.path)
    }

    // MARK: - Provider 로딩 (앱 시작 시)

    func loadModelsIfAvailable() async {
        await appState.switchSTTProvider(to: appState.settings.sttProviderType)
        await appState.switchLLMProvider(to: appState.settings.llmProviderType)
        refreshCachedModelStates()

        // MLX Audio가 다운로드되어 있고 현재 활성 프로바이더가 아니면 백그라운드 warmup
        if mlxAudioDownloaded, appState.settings.sttProviderType != .mlxAudio {
            Task { await warmupMLXAudioInBackground() }
        }
    }

    /// MLX Audio 프로세스를 백그라운드에서 미리 시작하여 콜드 스타트 제거
    func warmupMLXAudioInBackground() async {
        guard appState.prewarmedMLXProvider == nil else { return }
        let provider = MLXAudioProvider(modelId: appState.settings.mlxAudioModelId)
        do {
            try await provider.setup()
            appState.prewarmedMLXProvider = provider
        } catch {
            // warmup 실패 시 무시 — 사용자가 전환할 때 콜드 스타트로 폴백
        }
    }

    // MARK: - Downloads 탭 전용 (provider 전환 없이 다운로드)

    func downloadWhisperKitModel() async {
        let originalType = appState.settings.sttProviderType
        isWhisperKitDownloading = true

        await appState.switchSTTProvider(to: .whisperKit)
        whisperKitDownloaded = true

        if originalType != .whisperKit {
            await appState.switchSTTProvider(to: originalType)
        }
        isWhisperKitDownloading = false
    }

    func downloadMLXAudioModel() async {
        let originalType = appState.settings.sttProviderType
        isMLXAudioDownloading = true
        mlxAudioDownloadState = .loading

        await appState.switchSTTProvider(to: .mlxAudio)

        if appState.whisperModelState.isReady {
            mlxAudioDownloaded = true
            mlxAudioDownloadState = .ready
        } else if case let .error(msg) = appState.whisperModelState {
            mlxAudioDownloadState = .error(msg)
        }

        if originalType != .mlxAudio {
            await appState.switchSTTProvider(to: originalType)
            // 다운로드 성공 후 백그라운드 warmup (다음번 사용 시 콜드 스타트 제거)
            if mlxAudioDownloaded {
                Task { await warmupMLXAudioInBackground() }
            }
        }
        isMLXAudioDownloading = false
    }

    func downloadLocalLLMModel() async {
        let originalType = appState.settings.llmProviderType
        isLocalLLMDownloading = true

        await appState.switchLLMProvider(to: .local)
        localLLMDownloaded = appState.llmModelState.isReady

        if originalType != .local {
            await appState.switchLLMProvider(to: originalType)
        }
        isLocalLLMDownloading = false
    }

    // MARK: - 기존 메서드 (STT/LLM 탭에서 사용)

    func downloadWhisperModel() async throws {
        isWhisperKitDownloading = true
        whisperModelInfo.state = .downloading(progress: 0)
        do {
            await appState.switchSTTProvider(to: appState.settings.sttProviderType)
            if case let .error(msg) = appState.whisperModelState {
                throw NSError(domain: "ModelManager", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            whisperModelInfo.state = .ready
            whisperKitDownloaded = true
        } catch {
            whisperModelInfo.state = .error(error.localizedDescription)
            throw error
        }
        isWhisperKitDownloading = false
    }

    func downloadLLMModel() async throws {
        isLocalLLMDownloading = true
        llmModelInfo.state = .downloading(progress: 0)
        do {
            await appState.switchLLMProvider(to: .local)
            if case let .error(msg) = appState.llmModelState {
                throw NSError(domain: "ModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            llmModelInfo.state = .ready
            localLLMDownloaded = true
        } catch {
            llmModelInfo.state = .error(error.localizedDescription)
            throw error
        }
        isLocalLLMDownloading = false
    }

    func downloadAllModels(
        whisperProgress: @escaping (Double) -> Void,
        llmProgress: @escaping (Double) -> Void
    ) async throws {
        try await downloadWhisperModel()
        whisperProgress(1.0)
        try await downloadLLMModel()
        llmProgress(1.0)
    }

    // MARK: - 삭제

    func deleteWhisperModel() {
        sttService.unloadModel()
        Task { await appState.sttProvider?.teardown() }
        appState.sttProvider = nil
        whisperModelInfo.state = .notDownloaded
        appState.whisperModelState = .notDownloaded
        whisperKitDownloaded = false
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface")
        try? FileManager.default.removeItem(at: cacheDir)
    }

    func deleteLLMModel() {
        llmService.unloadModel()
        Task { await appState.llmProvider?.teardown() }
        appState.llmProvider = nil
        llmModelInfo.state = .notDownloaded
        appState.llmModelState = .notDownloaded
        localLLMDownloaded = false
    }

    func deleteMLXAudioModel() {
        if appState.settings.sttProviderType == .mlxAudio {
            Task { await appState.sttProvider?.teardown() }
            appState.sttProvider = nil
            appState.whisperModelState = .notDownloaded
        }
        mlxAudioDownloaded = false
        mlxAudioDownloadState = .notDownloaded
        // HuggingFace 캐시 삭제
        let cacheDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/models--mlx-community--Qwen3-ASR-1.7B-8bit")
        try? FileManager.default.removeItem(at: cacheDir)
    }

    var totalDiskUsage: Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: Self.modelsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
