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
    /// 모델별 다운로드 진행률 (0.0-1.0). 미포함 = indeterminate.
    /// 키는 repoId 또는 특수 키("whisperKit"). LLM/STT 모두 공통.
    @Published var downloadProgress: [String: Double] = [:]
    /// 모델별 다운로드 된 바이트 수 — UI에 "31 MB / 6.9 GB" 같은 실측 표기에 사용
    @Published var downloadedBytes: [String: Int64] = [:]
    /// 다운로드 대기 중인 LLM 모델 ID (직렬 처리 — URLSession 풀 경쟁 방지)
    @Published var queuedModelIds: Set<String> = []
    @Published var mlxAudioDownloadState: ModelState = .notDownloaded

    /// LLM 다운로드 직렬화 체인 — 동시 다운로드 시 URLSession이 starvation되어 0%에 stuck되는 문제 방지
    private var llmDownloadChain: Task<Void, Never> = Task {}
    /// 모델별 실행 중인 다운로드 Task — 취소를 위해 보관
    private var activeDownloadTasks: [String: Task<Void, Never>] = [:]

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

        // WhisperKit 진행률을 공통 dict로 포워딩
        appState.$whisperDownloadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                guard let self else { return }
                if self.isWhisperKitDownloading, progress > 0, progress < 1 {
                    self.downloadProgress[Self.whisperKitRepoId] = progress
                }
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
        if !isWhisperKitDownloading, Self.isWhisperKitCached() {
            modelCacheStates[Self.whisperKitRepoId] = true
        }

        // STT: MLX Audio
        let mlxId = appState.settings.mlxAudioModelId
        if !isMLXAudioDownloading, Self.isModelCached(repoId: mlxId) {
            modelCacheStates[mlxId] = true
            if mlxAudioDownloadState == .notDownloaded {
                mlxAudioDownloadState = .ready
            }
        }

        // LLM 모델 — 다운로드 진행 중은 skip
        for spec in LocalModelSpec.supported {
            guard !downloadingModelIds.contains(spec.id) else { continue }
            if Self.isModelCached(repoId: spec.id) {
                modelCacheStates[spec.id] = true
            }
        }
    }

    /// 비동기 캐시 상태 갱신 — FileManager stat 호출을 background로 오프로드.
    /// 뷰 onAppear/task에서 호출해도 main thread가 block되지 않음.
    func refreshAllCacheStatesAsync() async {
        let mlxId = appState.settings.mlxAudioModelId
        let whisperId = Self.whisperKitRepoId
        let downloading = downloadingModelIds
        let whisperDownloading = isWhisperKitDownloading
        let mlxDownloading = isMLXAudioDownloading
        let llmIds = LocalModelSpec.supported.map(\.id)
        let fresh: [String: Bool] = await Task.detached {
            var out: [String: Bool] = [:]
            if !whisperDownloading { out[whisperId] = Self.isWhisperKitCached() }
            if !mlxDownloading { out[mlxId] = Self.isModelCached(repoId: mlxId) }
            for id in llmIds where !downloading.contains(id) {
                out[id] = Self.isModelCached(repoId: id)
            }
            return out
        }.value
        // OR upgrade: 한번 true로 기록된 건 유지
        for (id, exists) in fresh where exists {
            modelCacheStates[id] = true
        }
        if (modelCacheStates[mlxId] ?? false), mlxAudioDownloadState == .notDownloaded {
            mlxAudioDownloadState = .ready
        }
    }

    /// 앱 최초 시작 시 1회만 호출 — disk를 SSOT로 강제 동기화. stale UserDefaults 정리.
    /// 이후 일반 리프레시는 OR upgrade only(`refreshAllCacheStates`)로 수행.
    private func reconcileWithDisk() {
        modelCacheStates[Self.whisperKitRepoId] = Self.isWhisperKitCached()

        let mlxId = appState.settings.mlxAudioModelId
        let mlxCached = Self.isModelCached(repoId: mlxId)
        modelCacheStates[mlxId] = mlxCached
        mlxAudioDownloadState = mlxCached ? .ready : .notDownloaded

        for spec in LocalModelSpec.supported {
            modelCacheStates[spec.id] = Self.isModelCached(repoId: spec.id)
        }
    }

    func isLLMModelCached(_ modelId: String) -> Bool {
        modelCacheStates[modelId] ?? Self.isModelCached(repoId: modelId)
    }

    /// 캐시 판정 — 정상 다운 모델을 false로 잘못 판정하지 않도록 관대하게,
    /// 단 부분 다운로드(디렉토리만 생기고 실제 파일 없음)는 걸러냄.
    /// 조건: 디렉토리 존재 + `config.json` + 크기 10MB 이상인 `.safetensors` 최소 1개
    nonisolated static func isModelCached(repoId: String) -> Bool {
        let fm = FileManager.default
        let candidates = [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/models/\(repoId)"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub/models--" + repoId.replacingOccurrences(of: "/", with: "--"))
        ]
        return candidates.contains { dir in Self.directoryHasUsableModel(at: dir) }
    }

    nonisolated private static func directoryHasUsableModel(at dir: URL) -> Bool {
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
        // HF hub 캐시는 snapshots/<hash>/의 symlink → blobs/의 실제 파일 구조.
        // URL.fileSizeKey는 symlink 자체 크기(76B)를 반환하므로, resolvingSymlinksInPath()로 타겟 크기를 읽는다.
        for url in contents {
            let n = url.lastPathComponent
            guard n.hasSuffix(".safetensors") else { continue }
            let resolved = url.resolvingSymlinksInPath()
            if let attrs = try? fm.attributesOfItem(atPath: resolved.path),
               let size = attrs[.size] as? NSNumber,
               size.int64Value >= 10_000_000
            {
                return true
            }
        }
        return false
    }

    /// WhisperKit 모델 캐시 판정 — 자체 포맷 사용 (~/Documents/huggingface/models/...)
    nonisolated static func isWhisperKitCached() -> Bool {
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
        let hfSlug = repoId.replacingOccurrences(of: "/", with: "--")
        return [
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/models/\(repoId)"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub/models--" + hfSlug),
            fm.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub/.locks/models--" + hfSlug)
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
        guard !downloadingModelIds.contains(modelId), !queuedModelIds.contains(modelId) else {
            return
        }
        modelErrors.removeValue(forKey: modelId)
        queuedModelIds.insert(modelId)

        let previousChain = llmDownloadChain
        let newTask = Task { [weak self] in
            await previousChain.value
            guard let self else { return }
            // 체인 대기 중 취소되면 queued 상태에서 바로 탈출
            if Task.isCancelled {
                await MainActor.run { [weak self] in
                    self?.queuedModelIds.remove(modelId)
                    self?.activeDownloadTasks.removeValue(forKey: modelId)
                }
                return
            }
            await self.performLLMDownload(modelId: modelId)
            await MainActor.run { [weak self] in
                self?.activeDownloadTasks.removeValue(forKey: modelId)
            }
        }
        llmDownloadChain = newTask
        activeDownloadTasks[modelId] = newTask
        await newTask.value
    }

    /// 다운로드 취소 — queued 상태와 실행 중 상태 모두 지원.
    /// URLSession은 Task 취소를 honor하므로 loadContainer 내부의 다운로드가 중단된다.
    func cancelLLMDownload(modelId: String) {
        activeDownloadTasks[modelId]?.cancel()
        queuedModelIds.remove(modelId)
        downloadingModelIds.remove(modelId)
        downloadProgress.removeValue(forKey: modelId)
        downloadedBytes.removeValue(forKey: modelId)
        modelErrors.removeValue(forKey: modelId)
    }

    private func performLLMDownload(modelId: String) async {
        queuedModelIds.remove(modelId)
        downloadingModelIds.insert(modelId)
        downloadProgress[modelId] = 0
        downloadedBytes[modelId] = 0

        let spec = LocalModelSpec.find(modelId)

        // URLSession downloadTask는 shard를 temp 위치에 쓰다가 완료 시점에만 blobs/로 atomic move한다.
        // 따라서 blobs/ 디렉토리 polling은 shard 완료마다 "양자점프"하고 다운로드 중엔 0%에 stuck처럼 보임.
        // swift-huggingface가 주입하는 Foundation.Progress는 URLSession delegate가 중간 바이트를 실시간
        // 갱신하므로 이걸 snapshot으로 잡아서 polling하면 정확한 진행률을 얻을 수 있다.
        let snapshot = ProgressSnapshot()
        let progressHandler: @Sendable (Foundation.Progress) -> Void = { p in
            snapshot.update(p)
        }
        let pollerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { break }
                let liveBytes = snapshot.completedUnitCount
                let liveTotal = snapshot.totalUnitCount
                let diskBytes = Self.cachedBlobsSize(repoId: modelId)
                // Progress는 완료된 shard만 반영하는 경우가 있어 disk 실측 바이트가 더 클 수 있음 → max
                let reportedBytes = max(liveBytes, diskBytes)
                await MainActor.run { [weak self] in
                    self?.downloadedBytes[modelId] = reportedBytes
                    if let expected = spec?.sizeBytes, expected > 0 {
                        self?.downloadProgress[modelId] = min(Double(reportedBytes) / Double(expected), 0.99)
                    } else if liveTotal > 0 {
                        self?.downloadProgress[modelId] = min(Double(liveBytes) / Double(liveTotal), 0.99)
                    }
                }
            }
        }

        do {
            if spec?.runtime == .python {
                let provider = MLXLMPythonProvider(modelId: modelId) { [weak self] phase in
                    guard let self else { return }
                    switch phase {
                    case .uvSync:
                        self.downloadProgress.removeValue(forKey: modelId)
                    case let .downloading(progress):
                        self.downloadProgress[modelId] = progress
                    case .loading:
                        self.downloadProgress.removeValue(forKey: modelId)
                    }
                }
                try await provider.setup()
                await provider.teardown()
            } else if spec?.capability == .vision {
                let config = ModelConfiguration(id: modelId)
                let _ = try await VLMModelFactory.shared.loadContainer(
                    from: SerialHubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: config,
                    progressHandler: progressHandler
                )
            } else {
                let config = ModelConfiguration(id: modelId)
                let _ = try await LLMModelFactory.shared.loadContainer(
                    from: SerialHubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: config,
                    progressHandler: progressHandler
                )
            }
            modelCacheStates[modelId] = true
        } catch is CancellationError {
            // 유저 취소 — 에러 메시지 노출 안 함
        } catch {
            if !Task.isCancelled {
                modelErrors[modelId] = error.localizedDescription
            }
        }

        pollerTask.cancel()
        downloadingModelIds.remove(modelId)
        downloadProgress.removeValue(forKey: modelId)
        downloadedBytes.removeValue(forKey: modelId)
    }

    /// 특정 모델의 실제 캐시 경로 반환 — Finder에서 열기용.
    /// MLX 모델은 `~/.cache/huggingface/hub/models--<repo>/`에 저장.
    func cachedModelDirectory(repoId: String) -> URL? {
        let fm = FileManager.default
        let dir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/models--" + repoId.replacingOccurrences(of: "/", with: "--"))
        return fm.fileExists(atPath: dir.path) ? dir : nil
    }

    /// HuggingFace hub 캐시 루트 — 모든 MLX 모델의 부모 디렉토리.
    static var huggingFaceHubDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub")
    }

    /// HF hub 캐시의 blobs/ 디렉토리 총 바이트. progressHandler 대신 disk polling으로 진행률 산출.
    static func cachedBlobsSize(repoId: String) -> Int64 {
        let fm = FileManager.default
        let blobsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache/huggingface/hub/models--" + repoId.replacingOccurrences(of: "/", with: "--"))
            .appendingPathComponent("blobs")
        guard let contents = try? fm.contentsOfDirectory(at: blobsDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for url in contents {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    // MARK: - STT 다운로드

    func downloadWhisperKitModel() async {
        let originalType = appState.settings.sttProviderType
        isWhisperKitDownloading = true
        downloadProgress[Self.whisperKitRepoId] = 0

        await appState.switchSTTProvider(to: .whisperKit)
        modelCacheStates[Self.whisperKitRepoId] = true

        if originalType != .whisperKit {
            await appState.switchSTTProvider(to: originalType)
        }
        isWhisperKitDownloading = false
        downloadProgress.removeValue(forKey: Self.whisperKitRepoId)
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
        // 진행 중/대기 중 다운로드 먼저 취소 — 취소 없이 지우면 URLSession이 계속 write해서 파일이 재생성됨.
        if downloadingModelIds.contains(modelId) || queuedModelIds.contains(modelId) {
            cancelLLMDownload(modelId: modelId)
        }
        if modelId == appState.settings.llmModelId {
            Task { await appState.llmProvider?.teardown() }
            appState.llmProvider = nil
            appState.llmModelState = .notDownloaded
        }
        let fm = FileManager.default
        for path in modelCachePaths(repoId: modelId) {
            guard fm.fileExists(atPath: path.path) else { continue }
            do {
                try fm.removeItem(at: path)
            } catch {
                modelErrors[modelId] = "삭제 실패: \(error.localizedDescription)"
            }
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

// MARK: - ProgressSnapshot

/// swift-huggingface가 주입하는 `Foundation.Progress`는 nonisolated 상태에서 URLSession delegate로부터
/// 실시간 업데이트되지만, SwiftUI 바인딩에 직접 쓸 수 없어 MainActor에서 polling해야 한다.
/// 이 박스는 non-MainActor progressHandler에서 바이트 수를 기록하고, MainActor pollerTask가 읽는다.
private final class ProgressSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var _completed: Int64 = 0
    private var _total: Int64 = 0

    func update(_ progress: Foundation.Progress) {
        let c = progress.completedUnitCount
        let t = progress.totalUnitCount
        lock.lock()
        _completed = c
        _total = t
        lock.unlock()
    }

    var completedUnitCount: Int64 {
        lock.lock(); defer { lock.unlock() }
        return _completed
    }

    var totalUnitCount: Int64 {
        lock.lock(); defer { lock.unlock() }
        return _total
    }
}

// MARK: - SerialHubDownloader

/// `#hubDownloader()` 매크로가 `maxConcurrentDownloads: 8`로 하드코딩되어, 큰 모델(7GB+)에서
/// URLSession이 shard lock만 잡은 채 네트워크 0바이트로 stall되는 회귀를 유발. 동시성을 2로
/// 낮춘 커스텀 Downloader로 우회한다 (swift-huggingface 3.x의 `downloadSnapshot`
/// `maxConcurrentDownloads` 파라미터 직접 지정).
private struct SerialHubDownloader: MLXLMCommon.Downloader {
    private let client: HuggingFace.HubClient
    private let maxConcurrent: Int

    init(maxConcurrent: Int = 2) {
        self.client = HuggingFace.HubClient()
        self.maxConcurrent = maxConcurrent
    }

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Foundation.Progress) -> Void
    ) async throws -> URL {
        guard let repoID = HuggingFace.Repo.ID(rawValue: id) else {
            throw HuggingFaceDownloaderError.invalidRepositoryID(id)
        }
        return try await client.downloadSnapshot(
            of: repoID,
            revision: revision ?? "main",
            matching: patterns,
            maxConcurrentDownloads: maxConcurrent,
            progressHandler: { @MainActor progress in
                progressHandler(progress)
            }
        )
    }
}
