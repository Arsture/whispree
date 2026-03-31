import Combine
import Foundation
import MLXLLM
import MLXVLM
import MLXLMCommon

@MainActor
final class ModelManager: ObservableObject {
    @Published var whisperModelInfo = ModelInfo.whisperLargeV3Turbo
    @Published var isWhisperKitDownloading = false
    @Published var isMLXAudioDownloading = false
    var isDownloading: Bool {
        isWhisperKitDownloading || isMLXAudioDownloading || !downloadingModelIds.isEmpty
    }

    // MARK: - 통합 모델 캐시 상태 (STT + LLM, SSOT)

    /// 모델별 캐시 존재 여부 — 키: HuggingFace repo ID (모든 모델 통합)
    @Published var modelCacheStates: [String: Bool] = [:] {
        didSet { persistCacheStates() }
    }
    /// 현재 다운로드 중인 모델 ID 세트 (병렬 다운로드 지원)
    @Published var downloadingModelIds: Set<String> = []
    /// 모델별 에러 메시지
    @Published var modelErrors: [String: String] = [:]
    @Published var mlxAudioDownloadState: ModelState = .notDownloaded

    private static let cacheStatesKey = "WhispreeModelCacheStates"

    // MARK: - 레포 ID 상수

    private static let whisperKitRepoId = "argmaxinc/whisperkit-coreml"

    private let appState: AppState
    private let sttService: STTService
    private var cancellables = Set<AnyCancellable>()

    static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Whispree/Models", isDirectory: true)
    }

    // MARK: - Computed (SSOT에서 파생)

    var whisperKitDownloaded: Bool { modelCacheStates[Self.whisperKitRepoId] ?? false }
    var mlxAudioDownloaded: Bool { modelCacheStates[appState.settings.mlxAudioModelId] ?? false }
    var localLLMDownloaded: Bool { modelCacheStates[appState.settings.llmModelId] ?? false }

    init(appState: AppState, sttService: STTService) {
        self.appState = appState
        self.sttService = sttService
        createModelsDirectoryIfNeeded()
        loadPersistedCacheStates()
        observeProviderStates()
        refreshAllCacheStates()
    }

    // MARK: - Persistence

    private func loadPersistedCacheStates() {
        if let saved = UserDefaults.standard.dictionary(forKey: Self.cacheStatesKey) as? [String: Bool] {
            modelCacheStates = saved
        }
        // 이전 분리 키에서 마이그레이션
        if let oldLLM = UserDefaults.standard.dictionary(forKey: "WhispreeLLMCacheStates") as? [String: Bool] {
            for (k, v) in oldLLM where v { modelCacheStates[k] = true }
            UserDefaults.standard.removeObject(forKey: "WhispreeLLMCacheStates")
        }
        if let oldSTT = UserDefaults.standard.dictionary(forKey: "WhispreeSTTCacheStates") as? [String: Bool] {
            if oldSTT["whisperKit"] == true { modelCacheStates[Self.whisperKitRepoId] = true }
            if oldSTT["mlxAudio"] == true { modelCacheStates[appState.settings.mlxAudioModelId] = true }
            UserDefaults.standard.removeObject(forKey: "WhispreeSTTCacheStates")
        }
        if mlxAudioDownloaded { mlxAudioDownloadState = .ready }
    }

    private func persistCacheStates() {
        UserDefaults.standard.set(modelCacheStates, forKey: Self.cacheStatesKey)
    }

    private func observeProviderStates() {
        appState.$whisperModelState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.whisperModelInfo.state = state
            }
            .store(in: &cancellables)
    }

    private func createModelsDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: Self.modelsDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - 캐시 상태 확인

    /// 전체 지원 모델의 캐시 상태를 확인 (OR: 한번 true면 삭제 전까지 유지)
    func refreshAllCacheStates() {
        // STT 모델
        modelCacheStates[Self.whisperKitRepoId] = whisperKitDownloaded || isModelCached(repoId: Self.whisperKitRepoId)
        let mlxId = appState.settings.mlxAudioModelId
        modelCacheStates[mlxId] = mlxAudioDownloaded || isModelCached(repoId: mlxId)

        if mlxAudioDownloaded, mlxAudioDownloadState == .notDownloaded {
            mlxAudioDownloadState = .ready
        }

        // LLM 모델
        for spec in LocalModelSpec.supported {
            modelCacheStates[spec.id] = (modelCacheStates[spec.id] ?? false) || isModelCached(repoId: spec.id)
        }
    }

    func isLLMModelCached(_ modelId: String) -> Bool {
        modelCacheStates[modelId] ?? isModelCached(repoId: modelId)
    }

    private func isModelCached(repoId: String) -> Bool {
        let fm = FileManager.default
        let cacheDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
        let modelDir = cacheDir.appendingPathComponent("models--" + repoId.replacingOccurrences(of: "/", with: "--"))
        return fm.fileExists(atPath: modelDir.path)
    }

    private func huggingFaceCachePath(repoId: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/models--" + repoId.replacingOccurrences(of: "/", with: "--"))
    }

    // MARK: - Provider 로딩 (앱 시작 시)

    func loadModelsIfAvailable() async {
        await appState.switchSTTProvider(to: appState.settings.sttProviderType)
        await appState.switchLLMProvider(to: appState.settings.llmProviderType)
        refreshAllCacheStates()

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
        } catch {}
    }

    // MARK: - LLM 모델 다운로드 (provider 전환 없이, 병렬 가능)

    func downloadLLMModel(modelId: String) async {
        guard !downloadingModelIds.contains(modelId) else { return }
        downloadingModelIds.insert(modelId)
        modelErrors.removeValue(forKey: modelId)

        do {
            let config = ModelConfiguration(id: modelId)
            let spec = LocalModelSpec.find(modelId)

            if spec?.capability == .vision {
                let _ = try await VLMModelFactory.shared.loadContainer(configuration: config) { _ in }
            } else {
                let _ = try await LLMModelFactory.shared.loadContainer(configuration: config) { _ in }
            }
            modelCacheStates[modelId] = true
        } catch {
            modelErrors[modelId] = error.localizedDescription
        }

        downloadingModelIds.remove(modelId)
    }

    // MARK: - STT 다운로드

    func downloadWhisperKitModel() async {
        let originalType = appState.settings.sttProviderType
        isWhisperKitDownloading = true

        await appState.switchSTTProvider(to: .whisperKit)
        modelCacheStates[Self.whisperKitRepoId] = true

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
            modelCacheStates[appState.settings.mlxAudioModelId] = true
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

    // MARK: - 기존 메서드 (온보딩/초기 설정)

    func downloadWhisperModel() async throws {
        isWhisperKitDownloading = true
        whisperModelInfo.state = .downloading(progress: 0)
        do {
            await appState.switchSTTProvider(to: appState.settings.sttProviderType)
            if case let .error(msg) = appState.whisperModelState {
                throw NSError(domain: "ModelManager", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            whisperModelInfo.state = .ready
            modelCacheStates[Self.whisperKitRepoId] = true
        } catch {
            whisperModelInfo.state = .error(error.localizedDescription)
            throw error
        }
        isWhisperKitDownloading = false
    }

    func downloadLLMModel() async throws {
        do {
            await appState.switchLLMProvider(to: .local)
            if case let .error(msg) = appState.llmModelState {
                throw NSError(domain: "ModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            modelCacheStates[appState.settings.llmModelId] = true
        } catch {
            throw error
        }
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
        modelCacheStates[Self.whisperKitRepoId] = false
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface")
        try? FileManager.default.removeItem(at: cacheDir)
    }

    func deleteLLMModel() {
        deleteLLMModel(modelId: appState.settings.llmModelId)
    }

    func deleteLLMModel(modelId: String) {
        if modelId == appState.settings.llmModelId {
            Task { await appState.llmProvider?.teardown() }
            appState.llmProvider = nil
            appState.llmModelState = .notDownloaded
        }
        let cachePath = huggingFaceCachePath(repoId: modelId)
        try? FileManager.default.removeItem(at: cachePath)
        modelCacheStates[modelId] = false
    }

    func deleteMLXAudioModel() {
        if appState.settings.sttProviderType == .mlxAudio {
            Task { await appState.sttProvider?.teardown() }
            appState.sttProvider = nil
            appState.whisperModelState = .notDownloaded
        }
        mlxAudioDownloadState = .notDownloaded
        modelCacheStates[appState.settings.mlxAudioModelId] = false
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
