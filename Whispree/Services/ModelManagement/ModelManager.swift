import Combine
import Foundation

@MainActor
final class ModelManager: ObservableObject {
    @Published var whisperModelInfo = ModelInfo.whisperLargeV3Turbo
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
    private var cancellables = Set<AnyCancellable>()

    static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whispree/Models", isDirectory: true)
    }

    init(appState: AppState, sttService: STTService) {
        self.appState = appState
        self.sttService = sttService
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

        // LLM 모델 ID 변경 시 다운로드 상태 재평가
        appState.$settings
            .map(\.llmModelId)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshLLMDownloadState()
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
        whisperKitDownloaded = whisperKitDownloaded || isModelCached(repoId: "argmaxinc/whisperkit-coreml")
        mlxAudioDownloaded = mlxAudioDownloaded || isModelCached(repoId: appState.settings.mlxAudioModelId)
        refreshLLMDownloadState()

        if mlxAudioDownloaded, mlxAudioDownloadState == .notDownloaded {
            mlxAudioDownloadState = .ready
        }
    }

    /// LLM 다운로드 상태만 재평가 (모델 ID 변경 시 호출)
    private func refreshLLMDownloadState() {
        localLLMDownloaded = isModelCached(repoId: appState.settings.llmModelId)
    }

    private func isModelCached(repoId: String) -> Bool {
        let fm = FileManager.default
        let cacheDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let modelDir = cacheDir.appendingPathComponent("models--" + repoId.replacingOccurrences(of: "/", with: "--"))
        return fm.fileExists(atPath: modelDir.path)
    }

    /// HuggingFace 캐시 경로 생성
    private func huggingFaceCachePath(repoId: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/models--" + repoId.replacingOccurrences(of: "/", with: "--"))
    }

    // MARK: - Provider 로딩 (앱 시작 시)

    func loadModelsIfAvailable() async {
        await appState.switchSTTProvider(to: appState.settings.sttProviderType)
        await appState.switchLLMProvider(to: appState.settings.llmProviderType)
        refreshCachedModelStates()

        if mlxAudioDownloaded, appState.settings.sttProviderType != .mlxAudio {
            Task { await warmupMLXAudioInBackground() }
        }
    }

    func warmupMLXAudioInBackground() async {
        guard appState.prewarmedMLXProvider == nil else { return }
        let provider = MLXAudioProvider(modelId: appState.settings.mlxAudioModelId)
        do {
            try await provider.setup()
            appState.prewarmedMLXProvider = provider
        } catch {
            // warmup 실패 시 무시
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
        do {
            await appState.switchLLMProvider(to: .local)
            if case let .error(msg) = appState.llmModelState {
                throw NSError(domain: "ModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            localLLMDownloaded = true
        } catch {
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
        Task { await appState.llmProvider?.teardown() }
        appState.llmProvider = nil
        appState.llmModelState = .notDownloaded
        localLLMDownloaded = false
        // 현재 선택된 모델의 캐시 삭제
        let cachePath = huggingFaceCachePath(repoId: appState.settings.llmModelId)
        try? FileManager.default.removeItem(at: cachePath)
    }

    func deleteMLXAudioModel() {
        if appState.settings.sttProviderType == .mlxAudio {
            Task { await appState.sttProvider?.teardown() }
            appState.sttProvider = nil
            appState.whisperModelState = .notDownloaded
        }
        mlxAudioDownloaded = false
        mlxAudioDownloadState = .notDownloaded
        let cachePath = huggingFaceCachePath(repoId: appState.settings.mlxAudioModelId)
        try? FileManager.default.removeItem(at: cachePath)
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
