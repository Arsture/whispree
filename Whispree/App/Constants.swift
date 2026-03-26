import Foundation

enum Constants {
    static let appName = "Whispree"
    static let bundleIdentifier = "com.whispree.app"

    enum Models {
        static let defaultWhisperModel = "openai_whisper-large-v3_turbo"
        static let defaultLLMModel = "mlx-community/Qwen3-4B-Instruct-2507-4bit"
        static let whisperModelSize: Int64 = 1_500_000_000
        static let llmModelSize: Int64 = 2_500_000_000
    }

    enum Limits {
        static let llmTimeoutSeconds: TimeInterval = 5.0
        static let maxHistoryEntries = 100
        static let maxRecordingDuration: TimeInterval = 120 // 2 minutes
        static let minAudioAmplitude: Float = 0.01
        static let maxLLMTokens = 200
    }

    enum Audio {
        static let sampleRate: Double = 16_000
        static let channels: UInt32 = 1
        static let bufferSize: UInt32 = 4_096
    }
}
