import Foundation

@MainActor
final class NoneProvider: LLMProvider {
    let name = "없음 (원문 사용)"
    let requiresNetwork = false

    func validate() -> ProviderValidation {
        .valid
    }

    func setup() async throws {
        // 설정 불필요
    }

    func teardown() async {
        // 해제 불필요
    }

    func correct(text: String, systemPrompt: String, glossary: [String]?, screenshot: Data? = nil) async throws -> String {
        text // 원문 그대로 반환
    }
}
