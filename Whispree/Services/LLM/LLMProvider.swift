import Foundation

/// LLM Provider Protocol - None / LocalText / LocalVision / OpenAI 간 전환 가능
@MainActor
protocol LLMProvider {
    var name: String { get }
    var requiresNetwork: Bool { get }
    /// Vision 모델 여부 — true이면 screenshots를 활용한 교정 가능
    var supportsVision: Bool { get }

    func validate() -> ProviderValidation
    func setup() async throws
    func teardown() async

    /// 텍스트 교정. glossary는 도메인 단어 세트에서 가져옴
    func correct(
        text: String,
        systemPrompt: String,
        glossary: [String]?,
        screenshots: [Data]
    ) async throws -> String
}

@MainActor
extension LLMProvider {
    var isReady: Bool {
        validate().isValid
    }
}

enum LLMError: LocalizedError {
    case modelNotLoaded
    case correctionFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
            case .modelNotLoaded: "LLM model is not loaded"
            case let .correctionFailed(msg): "Text correction failed: \(msg)"
            case .timeout: "Text correction timed out"
        }
    }
}
