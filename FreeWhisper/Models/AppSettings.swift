import Foundation

struct AppSettings: Codable {
    var recordingMode: RecordingMode = .pushToTalk
    var language: SupportedLanguage = .korean
    var isLLMEnabled: Bool = true
    var hasCompletedOnboarding: Bool = false
    var launchAtLogin: Bool = false
    var showOverlay: Bool = true
    var correctionMode: CorrectionMode = .standard
    var customLLMPrompt: String? = nil

    // Model preferences
    var whisperModelId: String = "openai_whisper-large-v3_turbo"
    var llmModelId: String = "mlx-community/Qwen3-4B-Instruct-2507-4bit"

    private static let storageKey = "FreeWhisperSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self = decoded
        }
        // Migrate old model ID to new default
        if llmModelId.contains("Qwen2.5") {
            llmModelId = "mlx-community/Qwen3-4B-Instruct-2507-4bit"
            save()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
