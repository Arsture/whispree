import Foundation

@MainActor
final class NoneProvider: LLMProvider {
    let name = "없음 (원문 사용)"
    let isReady = true
    let requiresNetwork = false

    func setup() async throws {
        // 설정 불필요
    }

    func teardown() async {
        // 해제 불필요
    }

    func correct(text: String, systemPrompt: String, glossary: [String]?) async throws -> String {
        return text  // 원문 그대로 반환
    }
}
