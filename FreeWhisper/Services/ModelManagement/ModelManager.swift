import Foundation
import Combine

@MainActor
final class ModelManager: ObservableObject {
    @Published var whisperModelInfo = ModelInfo.whisperLargeV3Turbo
    @Published var llmModelInfo = ModelInfo.qwen3_4B
    @Published var isDownloading = false

    private let sttService: STTService
    private let llmService: LLMService
    private var cancellables = Set<AnyCancellable>()

    static var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("FreeWhisper/Models", isDirectory: true)
    }

    init(sttService: STTService, llmService: LLMService) {
        self.sttService = sttService
        self.llmService = llmService
        createModelsDirectoryIfNeeded()
        observeServiceStates()
    }

    private func observeServiceStates() {
        // Sync LLM service model state → llmModelInfo.state (for progress updates)
        llmService.$modelState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.llmModelInfo.state = state
            }
            .store(in: &cancellables)

        // Sync STT service model state → whisperModelInfo.state
        sttService.$modelState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.whisperModelInfo.state = state
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
        // Load whisper model
        do {
            try await sttService.loadModel()
            whisperModelInfo.state = .ready
        } catch {
            whisperModelInfo.state = .error(error.localizedDescription)
        }

        // Load LLM model (uses HuggingFace cache if already downloaded)
        do {
            try await llmService.loadModel()
            llmModelInfo.state = .ready
        } catch {
            llmModelInfo.state = .notDownloaded
        }
    }

    func downloadWhisperModel() async throws {
        isDownloading = true
        whisperModelInfo.state = .downloading(progress: 0)

        do {
            // WhisperKit handles its own model downloading
            try await sttService.loadModel()
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
            try await llmService.loadModel()
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
        whisperModelInfo.state = .notDownloaded
        // WhisperKit manages its own cache, but we can clear it
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("huggingface")
        try? FileManager.default.removeItem(at: cacheDir)
    }

    func deleteLLMModel() {
        llmService.unloadModel()
        llmModelInfo.state = .notDownloaded
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
