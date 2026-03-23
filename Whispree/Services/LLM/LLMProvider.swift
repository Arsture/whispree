import Foundation

/// LLM Provider Protocol - None / Local(Qwen3) / OpenAI(GPT) 간 전환 가능
@MainActor
protocol LLMProvider {
    var name: String { get }
    var requiresNetwork: Bool { get }

    func validate() -> ProviderValidation
    func setup() async throws
    func teardown() async

    /// 텍스트 교정. glossary는 도메인 단어 세트에서 가져옴
    func correct(text: String, systemPrompt: String,
                 glossary: [String]?) async throws -> String
}

@MainActor
extension LLMProvider {
    var isReady: Bool { validate().isValid }
}
