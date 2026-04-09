import AppKit
import Combine
import Foundation

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
    /// 녹음 중 일정 시간 이상 무음이 지속되는 상태. TranscriptionOverlayView가
    /// "무음 스킵 중" 인디케이터로 전환하기 위해 사용.
    @Published var isThinkingPause: Bool = false

    // MARK: - Screenshots

    @Published var capturedScreenshots: [CapturedScreenshot] = []
    /// 스크린샷 선택 완료 시 호출되는 콜백 (선택된 이미지 Data 배열 전달)
    var screenshotSelectionCallback: (([Data]) -> Void)?
    /// 글로벌 키 이벤트 → ScreenshotSelectionView로 전달
    @Published var selectionKeyEvent: NSEvent?
    /// 미리보기 요청 콜백 → AppDelegate가 Quick Look 스타일 패널 표시
    var previewRequestCallback: ((CapturedScreenshot) -> Void)?

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
    let oauthService = OAuthService()
    private var authCancellables = Set<AnyCancellable>()

    // MARK: - Settings

    @Published var settings = AppSettings()

    // MARK: - History

    @Published var transcriptionHistory: [TranscriptionRecord] = [] {
        didSet { saveHistory() }
    }

    private static let historyKey = "WhispreeHistory"

    var isReady: Bool {
        sttProvider?.isReady ?? false
    }

    init() {
        // authService/oauthService의 @Published 변경을 AppState로 전파
        // (SwiftUI가 중첩 ObservableObject 변경을 자동 감지하지 않으므로)
        authService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &authCancellables)

        oauthService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &authCancellables)

        loadHistory()
    }

    // MARK: - Provider Management

    func switchSTTProvider(to type: STTProviderType) async {
        // 전환 시작 시 이전 에러 클리어
        whisperModelState = .loading

        // 이전 provider teardown (에러 무시 — 전환 중 teardown 실패는 예상된 동작)
        await sttProvider?.teardown()

        switch type {
            case .whisperKit:
                sttProvider = WhisperKitProvider()
            case .groq:
                sttProvider = GroqSTTProvider(apiKey: settings.groqApiKey)
            case .mlxAudio:
                sttProvider = MLXAudioProvider(modelId: settings.mlxAudioModelId)
        }
        do {
            try await sttProvider?.setup()
            let validation = sttProvider?.validate() ?? .valid
            whisperModelState = validation.isValid ? .ready : .error(validation.message)
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
                let spec = LocalModelSpec.find(settings.llmModelId)
                let provider: any LLMProvider
                if spec?.capability == .vision {
                    provider = LocalVisionProvider(modelId: settings.llmModelId)
                } else {
                    provider = LocalTextProvider(modelId: settings.llmModelId)
                }
                llmProvider = provider
                // Vision 모델은 스크린샷 자동 활성화
                if provider.supportsVision {
                    settings.isScreenshotContextEnabled = true
                    settings.save()
                }
                do {
                    try await provider.setup()
                    let validation = provider.validate()
                    llmModelState = validation.isValid ? .ready : .error(validation.message)
                } catch {
                    llmModelState = .error(error.localizedDescription)
                }
            case .openai:
                settings.isScreenshotContextEnabled = true
                settings.save()
                let provider = OpenAIProvider(
                    model: settings.openaiModel,
                    authService: authService,
                    oauthService: oauthService
                )
                llmProvider = provider
                do {
                    try await provider.setup()
                    let validation = provider.validate()
                    llmModelState = validation.isValid ? .ready : .error(validation.message)
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

    // MARK: - History Persistence

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(transcriptionHistory) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: Self.historyKey),
           let history = try? JSONDecoder().decode([TranscriptionRecord].self, from: data)
        {
            transcriptionHistory = history
        }
    }
}
