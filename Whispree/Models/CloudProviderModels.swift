import Foundation

// MARK: - Cloud LLM Service

/// OpenAI 호환 API를 사용하는 클라우드 LLM 서비스
enum CloudLLMService: String, Codable, CaseIterable {
    case openai
    case groq
    case gemini
    case deepseek
    case xai
    case openrouter

    var displayName: String {
        switch self {
        case .openai: "OpenAI API"
        case .groq: "Groq"
        case .gemini: "Google Gemini"
        case .deepseek: "DeepSeek"
        case .xai: "xAI (Grok)"
        case .openrouter: "OpenRouter"
        }
    }

    var baseURL: String {
        switch self {
        case .openai: "https://api.openai.com/v1"
        case .groq: "https://api.groq.com/openai/v1"
        case .gemini: "https://generativelanguage.googleapis.com/v1beta/openai"
        case .deepseek: "https://api.deepseek.com/v1"
        case .xai: "https://api.x.ai/v1"
        case .openrouter: "https://openrouter.ai/api/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .openai: "gpt-4.1-nano"
        case .groq: "openai/gpt-oss-120b"
        case .gemini: "gemini-2.5-flash"
        case .deepseek: "deepseek-chat"
        case .xai: "grok-4-1-fast-non-reasoning"
        case .openrouter: "google/gemini-2.5-flash"
        }
    }

    var presetModels: [CloudModelPreset] {
        switch self {
        case .openai:
            return [
                CloudModelPreset(id: "gpt-4.1-nano", displayName: "GPT-4.1 Nano", supportsVision: true, priceInfo: "$0.10 / $0.40"),
                CloudModelPreset(id: "gpt-4.1-mini", displayName: "GPT-4.1 Mini", supportsVision: true, priceInfo: "$0.40 / $1.60"),
                CloudModelPreset(id: "gpt-4.1", displayName: "GPT-4.1", supportsVision: true, priceInfo: "$2.00 / $8.00"),
                CloudModelPreset(id: "gpt-5.4-nano", displayName: "GPT-5.4 Nano", supportsVision: true, priceInfo: "$0.20 / $1.25"),
                CloudModelPreset(id: "gpt-5.4-mini", displayName: "GPT-5.4 Mini", supportsVision: true, priceInfo: "$0.75 / $4.50"),
                CloudModelPreset(id: "gpt-5.4", displayName: "GPT-5.4", supportsVision: true, priceInfo: "$2.50 / $15.00"),
                CloudModelPreset(id: "o3", displayName: "o3 (Reasoning)", supportsVision: true, priceInfo: "$2.00 / $8.00"),
                CloudModelPreset(id: "o4-mini", displayName: "o4-mini (Reasoning)", supportsVision: true, priceInfo: "$1.10 / $4.40"),
            ]
        case .groq:
            return [
                CloudModelPreset(id: "llama-3.1-8b-instant", displayName: "Llama 3.1 8B Instant", supportsVision: false, priceInfo: "$0.05 / $0.08"),
                CloudModelPreset(id: "openai/gpt-oss-20b", displayName: "GPT-OSS 20B", supportsVision: false, priceInfo: "$0.075 / $0.30"),
                CloudModelPreset(id: "openai/gpt-oss-120b", displayName: "GPT-OSS 120B", supportsVision: false, priceInfo: "$0.15 / $0.60"),
                CloudModelPreset(id: "llama-3.3-70b-versatile", displayName: "Llama 3.3 70B", supportsVision: false, priceInfo: "$0.59 / $0.79"),
                CloudModelPreset(id: "qwen/qwen3-32b", displayName: "Qwen3 32B", supportsVision: false, priceInfo: "$0.29 / $0.59"),
                CloudModelPreset(id: "meta-llama/llama-4-scout-17b-16e-instruct", displayName: "Llama 4 Scout (Vision)", supportsVision: true, priceInfo: "$0.11 / $0.34"),
            ]
        case .gemini:
            return [
                CloudModelPreset(id: "gemini-2.5-flash-lite", displayName: "Gemini 2.5 Flash Lite", supportsVision: true, priceInfo: "$0.10 / $0.40"),
                CloudModelPreset(id: "gemini-2.5-flash", displayName: "Gemini 2.5 Flash", supportsVision: true, priceInfo: "$0.30 / $2.50"),
                CloudModelPreset(id: "gemini-2.5-pro", displayName: "Gemini 2.5 Pro", supportsVision: true, priceInfo: "$1.25 / $10.00"),
                CloudModelPreset(id: "gemini-3-flash-preview", displayName: "Gemini 3 Flash (Preview)", supportsVision: true, priceInfo: "$0.50 / $3.00"),
                CloudModelPreset(id: "gemini-3.1-flash-lite-preview", displayName: "Gemini 3.1 Flash Lite (Preview)", supportsVision: true, priceInfo: "$0.25 / $1.50"),
                CloudModelPreset(id: "gemini-3.1-pro-preview", displayName: "Gemini 3.1 Pro (Preview)", supportsVision: true, priceInfo: "$2.00 / $12.00"),
            ]
        case .deepseek:
            return [
                CloudModelPreset(id: "deepseek-chat", displayName: "DeepSeek V3.2 (Chat)", supportsVision: false, priceInfo: "$0.27 / $1.10"),
                CloudModelPreset(id: "deepseek-reasoner", displayName: "DeepSeek V3.2 (Reasoner)", supportsVision: false, priceInfo: "$0.55 / $2.19"),
            ]
        case .xai:
            return [
                CloudModelPreset(id: "grok-4-1-fast-non-reasoning", displayName: "Grok 4.1 Fast", supportsVision: true, priceInfo: "$0.20 / $0.50"),
                CloudModelPreset(id: "grok-4-1-fast-reasoning", displayName: "Grok 4.1 Fast (Reasoning)", supportsVision: true, priceInfo: "$0.20 / $0.50"),
                CloudModelPreset(id: "grok-4.20-0309-non-reasoning", displayName: "Grok 4.20", supportsVision: true, priceInfo: "$2.00 / $6.00"),
                CloudModelPreset(id: "grok-4.20-0309-reasoning", displayName: "Grok 4.20 (Reasoning)", supportsVision: true, priceInfo: "$2.00 / $6.00"),
            ]
        case .openrouter:
            return [
                CloudModelPreset(id: "google/gemini-2.5-flash", displayName: "Gemini 2.5 Flash", supportsVision: true, priceInfo: "$0.30 / $2.50"),
                CloudModelPreset(id: "openai/gpt-5.4", displayName: "GPT-5.4", supportsVision: true, priceInfo: "$2.50 / $15.00"),
                CloudModelPreset(id: "anthropic/claude-sonnet-4.6", displayName: "Claude Sonnet 4.6", supportsVision: true, priceInfo: "$3.00 / $15.00"),
                CloudModelPreset(id: "deepseek/deepseek-chat", displayName: "DeepSeek Chat", supportsVision: false, priceInfo: "$0.25 / $0.38"),
            ]
        }
    }

    /// 해당 모델이 Vision을 지원하는지 확인. 프리셋에 없으면 서비스 기본값 반환.
    func supportsVision(modelId: String) -> Bool {
        if let preset = presetModels.first(where: { $0.id == modelId }) {
            return preset.supportsVision
        }
        // 프리셋에 없는 커스텀 모델: 서비스 기본값
        switch self {
        case .openai, .gemini, .xai: return true
        case .groq, .deepseek: return false
        case .openrouter: return false  // 불확실하므로 비활성
        }
    }
}

// MARK: - Model Preset

struct CloudModelPreset: Identifiable, Codable, Hashable {
    let id: String          // API model ID
    let displayName: String
    let supportsVision: Bool
    let priceInfo: String?  // "input / output per 1M tokens"
}

// MARK: - Claude Model

enum ClaudeModel: String, CaseIterable, Codable {
    case haiku45 = "claude-haiku-4-5"
    case sonnet46 = "claude-sonnet-4-6"
    case opus46 = "claude-opus-4-6"
    case sonnet45 = "claude-sonnet-4-5"
    case opus45 = "claude-opus-4-5"

    var displayName: String {
        switch self {
        case .haiku45: "Claude Haiku 4.5"
        case .sonnet46: "Claude Sonnet 4.6"
        case .opus46: "Claude Opus 4.6"
        case .sonnet45: "Claude Sonnet 4.5"
        case .opus45: "Claude Opus 4.5"
        }
    }

    var description: String {
        switch self {
        case .haiku45: "최고속 · 200k ctx · 교정에 충분"
        case .sonnet46: "균형 · 1M ctx · 코딩/에이전트 강점"
        case .opus46: "최고 성능 · 1M ctx · 복잡한 추론"
        case .sonnet45: "이전 세대 · 200k ctx"
        case .opus45: "이전 세대 · 200k ctx"
        }
    }

    var priceInfo: String {
        switch self {
        case .haiku45: "$1.00 / $5.00"
        case .sonnet46, .sonnet45: "$3.00 / $15.00"
        case .opus46, .opus45: "$5.00 / $25.00"
        }
    }

    var supportsVision: Bool { true }  // 모든 Claude 모델이 Vision 지원
}
