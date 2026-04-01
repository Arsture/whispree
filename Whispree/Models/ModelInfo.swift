import Foundation

struct ModelInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let sizeBytes: Int64
    let huggingFaceRepo: String
    var state: ModelState = .notDownloaded

    var sizeDescription: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    static let whisperLargeV3Turbo = ModelInfo(
        id: "openai_whisper-large-v3_turbo",
        name: "Whisper Large V3 Turbo",
        description: String(localized: "Fast and accurate STT model supporting 99 languages"),
        sizeBytes: 1_500_000_000,
        huggingFaceRepo: "argmaxinc/whisperkit-coreml"
    )

    // LLM 모델 정보는 LocalModelSpec에서 관리 (Single Source of Truth)
}

struct TranscriptionRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let originalText: String
    let correctedText: String?
    let language: String?

    var displayText: String {
        correctedText ?? originalText
    }
}

struct AppError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let isRecoverable: Bool

    static func sttError(_ message: String) -> AppError {
        AppError(title: "Transcription Error", message: message, isRecoverable: true)
    }

    static func llmError(_ message: String) -> AppError {
        AppError(title: "Correction Error", message: message, isRecoverable: true)
    }

    static func permissionError(_ message: String) -> AppError {
        AppError(title: "Permission Required", message: message, isRecoverable: false)
    }
}
