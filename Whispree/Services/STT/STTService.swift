import Foundation
import WhisperKit
import Combine

@MainActor
final class STTService: ObservableObject {
    @Published var modelState: ModelState = .notDownloaded
    @Published var partialResult: String = ""

    private var whisperKit: WhisperKit?

    func loadModel(modelId: String? = nil) async throws {
        modelState = .downloading(progress: 0)

        do {
            let config = WhisperKitConfig(
                model: modelId ?? "openai_whisper-large-v3_turbo",
                computeOptions: ModelComputeOptions(
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                )
            )
            modelState = .loading
            whisperKit = try await WhisperKit(config)
            modelState = .ready
        } catch {
            modelState = .error(error.localizedDescription)
            throw error
        }
    }

    func transcribe(audioBuffer: [Float], language: SupportedLanguage = .auto) async throws -> String {
        guard let whisperKit else {
            throw STTError.modelNotLoaded
        }

        let options = DecodingOptions(
            language: language == .auto ? nil : language.rawValue,
            wordTimestamps: false
        )

        let results = try await whisperKit.transcribe(audioArray: audioBuffer, decodeOptions: options)

        let fullText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return fullText
    }

    func transcribeStreaming(audioBuffer: [Float], language: SupportedLanguage = .auto) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                guard let whisperKit else {
                    continuation.finish()
                    return
                }

                let options = DecodingOptions(
                    language: language == .auto ? nil : language.rawValue,
                    wordTimestamps: true
                )

                do {
                    let results = try await whisperKit.transcribe(audioArray: audioBuffer, decodeOptions: options)

                    // Emit results progressively
                    var accumulated = ""
                    for result in results {
                        accumulated += result.text
                        continuation.yield(accumulated.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                } catch {
                    // Emit error as empty result
                }

                continuation.finish()
            }
        }
    }

    var isReady: Bool {
        whisperKit != nil && modelState == .ready
    }

    func unloadModel() {
        whisperKit = nil
        modelState = .notDownloaded
    }
}

enum STTError: LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "STT model is not loaded"
        case .transcriptionFailed(let msg): return "Transcription failed: \(msg)"
        case .emptyAudio: return "No audio was recorded"
        }
    }
}
