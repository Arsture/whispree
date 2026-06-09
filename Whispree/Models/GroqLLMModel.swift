import Foundation

/// Groq Cloud LLM 모델 레지스트리.
///
/// `meta-llama/llama-4-scout-17b-16e-instruct`만 비전 입력을 받는다. 나머지는 텍스트 전용.
/// TPM/RPM 제한은 Groq 콘솔(Free vs Developer plan)에 따라 달라지므로 여기서는 기록하지 않는다.
enum GroqLLMModel: String, CaseIterable, Codable {
    case llama4Scout = "meta-llama/llama-4-scout-17b-16e-instruct"
    case llama3_3_70b = "llama-3.3-70b-versatile"
    case llama3_1_8bInstant = "llama-3.1-8b-instant"
    case qwen3_32b = "qwen/qwen3-32b"
    case gptOss120b = "openai/gpt-oss-120b"
    case gptOss20b = "openai/gpt-oss-20b"

    var displayName: String {
        switch self {
            case .llama4Scout: "Llama 4 Scout 17B (Vision)"
            case .llama3_3_70b: "Llama 3.3 70B Versatile"
            case .llama3_1_8bInstant: "Llama 3.1 8B Instant"
            case .qwen3_32b: "Qwen3 32B"
            case .gptOss120b: "GPT-OSS 120B"
            case .gptOss20b: "GPT-OSS 20B"
        }
    }

    var description: String {
        switch self {
            case .llama4Scout: "Llama 4 Scout — Groq에서 유일하게 이미지 입력 지원 (17B MoE, 16 expert)"
            case .llama3_3_70b: "70B 범용 모델. 교정 품질 균형. (텍스트 전용)"
            case .llama3_1_8bInstant: "8B 초경량 모델. 응답 매우 빠름. (텍스트 전용)"
            case .qwen3_32b: "Qwen3 32B. 한국어 + 다국어 강함. (텍스트 전용)"
            case .gptOss120b: "OpenAI 오픈 웨이트 120B. 추론 우수. (텍스트 전용)"
            case .gptOss20b: "OpenAI 오픈 웨이트 20B. 속도/품질 균형. (텍스트 전용)"
        }
    }

    /// 스크린샷 컨텍스트 전달 가능 여부.
    var supportsVision: Bool {
        self == .llama4Scout
    }

    /// 교정 품질 점수 (0-100, 주관적).
    var qualityScore: Int {
        switch self {
            case .gptOss120b: 92
            case .llama3_3_70b: 88
            case .llama4Scout: 84
            case .qwen3_32b: 86
            case .gptOss20b: 78
            case .llama3_1_8bInstant: 70
        }
    }

    /// 예상 레이턴시 (ms). Groq는 토큰/초 매우 빠르므로 모델 크기 위주.
    var estimatedLatencyMs: Int {
        switch self {
            case .llama3_1_8bInstant: 200
            case .gptOss20b: 300
            case .qwen3_32b: 350
            case .llama4Scout: 400
            case .llama3_3_70b: 500
            case .gptOss120b: 700
        }
    }
}
