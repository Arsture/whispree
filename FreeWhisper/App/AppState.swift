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
    @Published var isRecording: Bool = false

    // MARK: - Model State
    @Published var whisperModelState: ModelState = .notDownloaded
    @Published var llmModelState: ModelState = .notDownloaded
    @Published var whisperDownloadProgress: Double = 0.0
    @Published var llmDownloadProgress: Double = 0.0

    // MARK: - Settings
    @Published var settings = AppSettings()

    // MARK: - History
    @Published var transcriptionHistory: [TranscriptionRecord] = []

    var isReady: Bool {
        whisperModelState == .ready
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
