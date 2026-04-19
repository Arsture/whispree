import Combine
import Foundation
import MLXLLM
import MLXVLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

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
        // 앱 최초 시작 시 1회만 disk와 강제 동기화 — stale UserDefaults(예: Cmd+Q로 중단된 다운로드) 정리
        reconcileWithDisk()
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

    /// OR upgrade only — 디스크에서 확실히 발견하면 true로 갱신, 이미 true면 유지.
    /// 다운로드 진행 중 또는 일시적 disk race로 인한 false flash를 방지.
    /// 명시적 downgrade는 delete/download 실패 경로에서만 수행.
    func refreshAllCacheStates() {
        // STT: WhisperKit
        if !isWhisperKitDownloading, isWhisperKitCached() {
            modelCacheStates[Self.whisperKitRepoId] = true
        }

        // STT: MLX Audio
        let mlxId = appState.settings.mlxAudioModelId
        if !isMLXAudioDownloading, isModelCached(repoId: mlxId) {
            modelCacheStates[mlxId] = true
            if mlxAudioDownloadState == .notDownloaded {
                mlxAudioDownloadState = .ready
            }
        }

        // LLM 모델 — 다운로드 진행 중은 skip
        for spec in LocalModelSpec.supported {
            guard !downloadingModelIds.contains(spec.id) else { continue }
            if isModelCached(repoId: spec.id) {
                modelCacheStates[spec.id] = true
            }
        }
    }

    /// 앱 최초 시작 시 1회만 호출 — disk를 SSOT로 강제 동기화. stale UserDefaults 정리.
    /// 이후 일반 리프레시는 OR upgrade only(`refreshAllCacheStates`)로 수행.
    private func reconcileWithDisk() {
        modelCacheStates[Self.whisperKitRepoId] = isWhisperKitCached()

        let mlxId = appState.settings.mlxAudioModelId
        let mlxCached = isModelCached(repoId: mlxId)
        modelCacheStates[mlxId] = mlxCached
        mlxAudioDownloadState = mlxCached ? .ready : .notDownloaded

        for spec in LocalModelSpec.supported {
            modelCacheStates[spec.id] = isModelCached(repoId: spec.id)
        }
    }

    func isLLMModelCached(_ modelId: String) -> Bool {
        isModelCached(repoId: modelId)
    }

    /// 캐시 판정 — 정상 다운 모델을 false로 잘못 판정하지 않도록 관대하게,
    /// 단 부분 다운로드(디렉토리만 생기고 실제 파일 없음)는 걸러냄.
    /// 조건: 디렉토리 존재 + `config.json` + 크기 10MB 이상인 `.safetensors` 최소 1개
    private func isModelCached(repoId: String) -> Bool {
        let fm = FileManager.default
        let candidates = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/models/\(repoId)"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub/models--" + repoId.replacingOccurrences(of: "/", with: "--"))
        ]
        return candidates.contains { dir in directoryHasUsableModel(at: dir) }
    }

    private func directoryHasUsableModel(at dir: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.path) else { return false }
        guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return false
        }
        let names = Set(contents.map { $0.lastPathComponent })

        // HuggingFace 표준 캐시는 snapshots/ 하위에 실제 파일 있음
        if names.contains("snapshots") {
            let snapshotsDir = dir.appendingPathComponent("snapshots")
            if let snapshots = try? fm.contentsOfDirectory(at: snapshotsDir, includingPropertiesForKeys: nil) {
                return snapshots.contains { directoryHasUsableModel(at: $0) }
            }
            return false
        }

        guard names.contains("config.json") else { return false }

        // .safetensors로 끝나는 파일 중 10MB 이상인 것이 하나라도 있으면 OK
        // (정상 모델의 가장 작은 shard도 수백 MB 이상이므로 10MB 기준은 충분히 관대)
        for url in contents {
            let n = url.lastPathComponent
            guard n.hasSuffix(".safetensors") else { continue }
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               size >= 10_000_000
            {
                return true
            }
        }
        return false
    }

    /// WhisperKit 모델 캐시 판정 — 자체 포맷 사용 (~/Documents/huggingface/models/...)
    private func isWhisperKitCached() -> Bool {
        let fm = FileManager.default
        let candidates = [
            fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/huggingface/models/" + Self.whisperKitRepoId),
            fm.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Caches/huggingface/models--" + Self.whisperKitRepoId.replacingOccurrences(of: "/", with: "--"))
        ]
        return candidates.contains { fm.fileExists(atPath: $0.path) }
    }

    private func modelCachePaths(repoId: String) -> [URL] {
        let fm = FileManager.default
        return [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/models/\(repoId)"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub/models--" + repoId.replacingOccurrences(of: "/", with: "--"))
        ]
    }

    // MARK: - Provider 로딩 (앱 시작 시)

    func loadModelsIfAvailable() async {
        await appState.switchSTTProvider(to: appState.settings.sttProviderType)
        await appState.switchLLMProvider(to: appState.settings.llmProviderType)
        refreshAllCacheStates()

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
                let _ = try await VLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: config
                ) { _ in }
            } else {
                let _ = try await LLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: config
                ) { _ in }
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
        for path in modelCachePaths(repoId: modelId) {
            try? FileManager.default.removeItem(at: path)
        }
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
        for path in modelCachePaths(repoId: appState.settings.mlxAudioModelId) {
            try? FileManager.default.removeItem(at: path)
        }
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
