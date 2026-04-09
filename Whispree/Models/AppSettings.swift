import Foundation

struct AppSettings: Codable {
    var recordingMode: RecordingMode = .pushToTalk
    var language: SupportedLanguage = .korean
    var isLLMEnabled: Bool = true
    var hasCompletedOnboarding: Bool = false
    var launchAtLogin: Bool = false
    var showOverlay: Bool = true
    var correctionMode: CorrectionMode = .standard
    var customLLMPrompt: String?

    // Model preferences
    var whisperModelId: String = "openai_whisper-large-v3_turbo"
    var llmModelId: String = "mlx-community/Qwen3-4B-Instruct-2507-4bit"
    var mlxAudioModelId: String = "mlx-community/Qwen3-ASR-1.7B-8bit"

    /// STT Provider
    var sttProviderType: STTProviderType = .whisperKit

    /// LLM Provider
    var llmProviderType: LLMProviderType = .none

    /// OpenAI 모델 선택
    var openaiModel: OpenAIModel = .gpt54

    /// Screenshot context
    var isScreenshotContextEnabled: Bool = false

    /// 스크린샷을 대상 앱에 이미지로 자동 붙여넣기
    var isScreenshotPasteEnabled: Bool = true

    /// Groq API
    var groqApiKey: String = ""

    /// 오디오 입력 채널 선택
    /// 0 = 자동 (모든 채널 평균 다운믹스, 기본값)
    /// 1~N = 특정 채널만 사용 (1-indexed)
    var audioInputChannel: Int = 0

    /// 도메인 단어 세트
    var domainWordSets: [DomainWordSet] = []

    private static let storageKey = "WhispreeSettings"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            self = decoded
        }
        // Migrate old model ID to new default
        if llmModelId.contains("Qwen2.5") {
            llmModelId = "mlx-community/Qwen3-4B-Instruct-2507-4bit"
            save()
        }
        // Migrate: 스크린샷 에이전트 전달 기본값 ON
        if isScreenshotContextEnabled, !isScreenshotPasteEnabled {
            isScreenshotPasteEnabled = true
            save()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

enum STTProviderType: String, Codable, CaseIterable {
    case whisperKit = "WhisperKit"
    case groq = "Groq"
    case mlxAudio = "MLX Audio"

    var displayName: String {
        switch self {
            case .whisperKit: "WhisperKit (로컬)"
            case .groq: "Groq Cloud (빠름)"
            case .mlxAudio: "MLX Audio (로컬)"
        }
    }
}

enum LLMProviderType: String, Codable, CaseIterable {
    case none = "없음 (원문 사용)"
    case local = "로컬 MLX"
    case openai = "OpenAI (GPT)"

    var displayName: String {
        switch self {
            case .none: "없음 (원문 사용)"
            case .local: "로컬 MLX"
            case .openai: "OpenAI (GPT)"
        }
    }

    /// 이전 rawValue에서 마이그레이션
    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        switch rawValue {
        case "로컬 LLM (Qwen3)": self = .local  // 이전 rawValue
        default:
            guard let value = LLMProviderType(rawValue: rawValue) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown LLMProviderType: \(rawValue)"))
            }
            self = value
        }
    }
}
