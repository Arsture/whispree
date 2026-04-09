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

    /// VAD (Voice Activity Detection) — 무음 구간 자동 제거
    /// STT 진입 전 공통 pre-processing, 모든 프로바이더(WhisperKit/Groq/MLX Audio)에 적용
    var vadEnabled: Bool = true

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

    /// 모든 필드를 `decodeIfPresent` + default fallback으로 처리.
    ///
    /// Swift의 synthesized `init(from:)`은 struct declaration의 default value를 **무시**하므로,
    /// 새 필드를 추가하면 기존 유저의 UserDefaults JSON 디코드가 `keyNotFound`로 실패하고
    /// **모든 설정이 리셋된다** (groqApiKey, correctionMode, domainWordSets 등 포함).
    ///
    /// 이를 방지하기 위해 custom `init(from:)`을 작성하여, 누락된 키는 모두 default로 폴백하도록 함.
    /// 앞으로 어떤 필드를 추가해도 backward compatible하게 유지됨.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.recordingMode = (try? c.decodeIfPresent(RecordingMode.self, forKey: .recordingMode)) ?? .pushToTalk
        self.language = (try? c.decodeIfPresent(SupportedLanguage.self, forKey: .language)) ?? .korean
        self.isLLMEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isLLMEnabled)) ?? true
        self.hasCompletedOnboarding = (try? c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)) ?? false
        self.launchAtLogin = (try? c.decodeIfPresent(Bool.self, forKey: .launchAtLogin)) ?? false
        self.showOverlay = (try? c.decodeIfPresent(Bool.self, forKey: .showOverlay)) ?? true
        self.correctionMode = (try? c.decodeIfPresent(CorrectionMode.self, forKey: .correctionMode)) ?? .standard
        self.customLLMPrompt = try? c.decodeIfPresent(String.self, forKey: .customLLMPrompt) ?? nil
        self.whisperModelId = (try? c.decodeIfPresent(String.self, forKey: .whisperModelId)) ?? "openai_whisper-large-v3_turbo"
        self.llmModelId = (try? c.decodeIfPresent(String.self, forKey: .llmModelId)) ?? "mlx-community/Qwen3-4B-Instruct-2507-4bit"
        self.mlxAudioModelId = (try? c.decodeIfPresent(String.self, forKey: .mlxAudioModelId)) ?? "mlx-community/Qwen3-ASR-1.7B-8bit"
        self.sttProviderType = (try? c.decodeIfPresent(STTProviderType.self, forKey: .sttProviderType)) ?? .whisperKit
        self.llmProviderType = (try? c.decodeIfPresent(LLMProviderType.self, forKey: .llmProviderType)) ?? .none
        self.openaiModel = (try? c.decodeIfPresent(OpenAIModel.self, forKey: .openaiModel)) ?? .gpt54
        self.isScreenshotContextEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isScreenshotContextEnabled)) ?? false
        self.isScreenshotPasteEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isScreenshotPasteEnabled)) ?? true
        self.groqApiKey = (try? c.decodeIfPresent(String.self, forKey: .groqApiKey)) ?? ""
        self.audioInputChannel = (try? c.decodeIfPresent(Int.self, forKey: .audioInputChannel)) ?? 0
        self.vadEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .vadEnabled)) ?? true
        self.domainWordSets = (try? c.decodeIfPresent([DomainWordSet].self, forKey: .domainWordSets)) ?? []
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
