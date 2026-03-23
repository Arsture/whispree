import Foundation

/// STT Provider Protocol - WhisperKit과 Lightning-SimulWhisper 간 전환 가능
/// @MainActor 제거: ML 추론은 백그라운드에서 실행되어야 함 (MainActor deadlock 방지)
protocol STTProvider: AnyObject, Sendable {
    var name: String { get }
    var isReady: Bool { get }
    var isAvailable: Bool { get }

    func setup() async throws
    func teardown() async

    func transcribe(audioBuffer: [Float], language: SupportedLanguage?,
                    promptTokens: [Int]?) async throws -> TranscriptionResult

    func transcribeStream(audioBuffer: [Float], language: SupportedLanguage?,
                          promptTokens: [Int]?) -> AsyncStream<PartialTranscription>
}

struct TranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?
}

struct TranscriptionSegment {
    let text: String
    let language: String?
    let words: [WordInfo]?
}

struct WordInfo {
    let word: String
    let start: Double
    let end: Double
}

struct PartialTranscription {
    let text: String
    let isFinal: Bool
}
