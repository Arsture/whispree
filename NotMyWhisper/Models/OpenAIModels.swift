import Foundation

enum OpenAIModel: String, CaseIterable, Codable {
    case gpt54 = "gpt-5.4"
    case gpt54mini = "gpt-5.4-mini"
    case gpt53codex = "gpt-5.3-codex"
    case gpt53codexSpark = "gpt-5.3-codex-spark"
    case gpt52codex = "gpt-5.2-codex"

    var displayName: String {
        switch self {
        case .gpt54: return "GPT-5.4 (Best)"
        case .gpt54mini: return "GPT-5.4 Mini (Fast)"
        case .gpt53codex: return "GPT-5.3 Codex"
        case .gpt53codexSpark: return "GPT-5.3 Codex Spark (Pro)"
        case .gpt52codex: return "GPT-5.2 Codex"
        }
    }

    var description: String {
        switch self {
        case .gpt54: return "최고 품질. 코딩 + 추론 통합 모델"
        case .gpt54mini: return "빠른 응답. 짧은 교정에 적합"
        case .gpt53codex: return "코딩 특화. 기술 용어 교정에 강함"
        case .gpt53codexSpark: return "초저지연. ChatGPT Pro 전용"
        case .gpt52codex: return "이전 버전. 안정성 우선"
        }
    }
}
