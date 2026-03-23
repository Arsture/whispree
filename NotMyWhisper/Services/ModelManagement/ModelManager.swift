import Foundation
import Combine

@MainActor
final class ModelManager: ObservableObject {
    @Published var whisperModelInfo = ModelInfo.whisperLargeV3Turbo
    @Published var llmModelInfo = ModelInfo.qwen3_4B
    @Published var isDownloading = false

    private let appState: AppState
    private let sttService: STTService
    private let llmService: LLMService
    private var cancellables = Set<AnyCancellable>()

    static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("NotMyWhisper/Models", isDirectory: true)
    }

    init(appState: AppState, sttService: STTService, llmService: LLMService) {
        self.appState = appState
        self.sttService = sttService
        self.llmService = llmService
        createModelsDirectoryIfNeeded()
        observeProviderStates()
    }

    private func observeProviderStates() {
        // Sync AppState provider states → model info for UI
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

    func loadModelsIfAvailable() async {
        // Load STT and LLM in parallel
        async let stt: Void = appState.switchSTTProvider(to: appState.settings.sttProviderType)
        async let llm: Void = appState.switchLLMProvider(to: appState.settings.llmProviderType)
        _ = await (stt, llm)
    }

    func downloadWhisperModel() async throws {
        isDownloading = true
        whisperModelInfo.state = .downloading(progress: 0)

        do {
            await appState.switchSTTProvider(to: appState.settings.sttProviderType)
            if case .error(let msg) = appState.whisperModelState {
                throw NSError(domain: "ModelManager", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            whisperModelInfo.state = .ready
        } catch {
            whisperModelInfo.state = .error(error.localizedDescription)
            throw error
        }

        isDownloading = false
    }

    func downloadLLMModel() async throws {
        isDownloading = true
        llmModelInfo.state = .downloading(progress: 0)

        do {
            await appState.switchLLMProvider(to: .local)
            if case .error(let msg) = appState.llmModelState {
                throw NSError(domain: "ModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            llmModelInfo.state = .ready
        } catch {
            llmModelInfo.state = .error(error.localizedDescription)
            throw error
        }

        isDownloading = false
    }

    func downloadAllModels(
        whisperProgress: @escaping (Double) -> Void,
        llmProgress: @escaping (Double) -> Void
    ) async throws {
        // Download sequentially to avoid memory pressure
        try await downloadWhisperModel()
        whisperProgress(1.0)

        try await downloadLLMModel()
        llmProgress(1.0)
    }

    func deleteWhisperModel() {
        sttService.unloadModel()
        Task { await appState.sttProvider?.teardown() }
        appState.sttProvider = nil
        whisperModelInfo.state = .notDownloaded
        appState.whisperModelState = .notDownloaded
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
