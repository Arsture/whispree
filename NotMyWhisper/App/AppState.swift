import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Transcription State
    @Published var transcriptionState: TranscriptionState = .idle
    @Published var partialText: String = ""
    @Published var finalText: String = ""
    @Published var correctedText: String = ""
    @Published var currentError: AppError?

    // MARK: - Audio
    @Published var currentAudioLevel: Float = 0.0
    @Published var frequencyBands: [Float] = Array(repeating: 0, count: 64)
    @Published var isRecording: Bool = false

    // MARK: - Model State
    @Published var whisperModelState: ModelState = .notDownloaded
    @Published var llmModelState: ModelState = .notDownloaded
    @Published var whisperDownloadProgress: Double = 0.0
    @Published var llmDownloadProgress: Double = 0.0

    // MARK: - Provider State
    @Published var sttProvider: (any STTProvider)?
    @Published var llmProvider: (any LLMProvider)?

    // MARK: - Auth
    let authService = CodexAuthService()

    // MARK: - Settings
    @Published var settings = AppSettings()

    // MARK: - History
    @Published var transcriptionHistory: [TranscriptionRecord] = []

    var isReady: Bool {
        sttProvider?.isReady ?? false
    }

    // MARK: - Provider Management

    func switchSTTProvider(to type: STTProviderType) async {
        await sttProvider?.teardown()
        whisperModelState = .loading
        switch type {
        case .whisperKit:
            sttProvider = WhisperKitProvider()
        case .groq:
            sttProvider = GroqSTTProvider(apiKey: settings.groqApiKey)
        case .lightning:
            sttProvider = LightningWhisperProvider()
        }
        do {
            try await sttProvider?.setup()
            whisperModelState = .ready
        } catch {
            whisperModelState = .error(error.localizedDescription)
        }
    }

    func switchLLMProvider(to type: LLMProviderType) async {
        await llmProvider?.teardown()
        llmModelState = .loading
        switch type {
        case .none:
            llmProvider = NoneProvider()
            llmModelState = .ready
        case .local:
            let provider = LocalLLMProvider(modelId: settings.llmModelId)
            llmProvider = provider
            do {
                try await provider.setup()
                llmModelState = .ready
            } catch {
                llmModelState = .error(error.localizedDescription)
            }
        case .openai:
            let provider = OpenAIProvider(model: settings.openaiModel, authService: authService)
            llmProvider = provider
            do {
                try await provider.setup()
                llmModelState = .ready
            } catch {
                llmModelState = .error(error.localizedDescription)
            }
        }
    }

    func addToHistory(original: String, corrected: String?) {
        let record = TranscriptionRecord(
            id: UUID(),
            timestamp: Date(),
            originalText: original,
            correctedText: corrected,
            language: nil
        )
        transcriptionHistory.insert(record, at: 0)
        // Keep last 100 entries
        if transcriptionHistory.count > 100 {
            transcriptionHistory = Array(transcriptionHistory.prefix(100))
        }
    }

    func clearError() {
        currentError = nil
    }
}
