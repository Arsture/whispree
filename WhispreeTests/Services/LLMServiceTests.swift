import XCTest
@testable import Whispree

@MainActor
final class LLMServiceTests: XCTestCase {

    // MARK: - Word Edit Distance

    func testWordEditDistanceIdentical() {
        let ratio = LLMService.testWordEditDistance("안녕하세요 반갑습니다", "안녕하세요 반갑습니다")
        XCTAssertEqual(ratio, 0.0)
    }

    func testWordEditDistanceOneWordChanged() {
        // "L&M" → "LLM" = 1 word changed out of 5
        let ratio = LLMService.testWordEditDistance(
            "이거 L&M 모델이 되개 잘하거든",
            "이거 LLM 모델이 되게 잘하거든"
        )
        // 5 words, 2 changed (L&M→LLM, 되개→되게) = 0.4
        XCTAssertLessThanOrEqual(ratio, 0.5)
    }

    func testWordEditDistanceCompletelyDifferent() {
        let ratio = LLMService.testWordEditDistance("hello world", "안녕 세상")
        XCTAssertEqual(ratio, 1.0)
    }

    func testWordEditDistanceEmpty() {
        let ratio = LLMService.testWordEditDistance("", "")
        XCTAssertEqual(ratio, 0.0)
    }

    func testWordEditDistanceOneEmpty() {
        let ratio = LLMService.testWordEditDistance("hello", "")
        XCTAssertEqual(ratio, 1.0)
    }

    func testWordEditDistanceKoreanCorrection() {
        // 한국어 음절 교정은 단어 단위에서 낮은 변경률을 보여야 함
        // "이거 L&M 모델이 되개 잘하거든" → "이거 LLM 모델이 되게 잘하거든"
        // 6 words, 2 changed = 0.33
        let ratio = LLMService.testWordEditDistance(
            "이거 L&M 모델이 되개 잘하거든",
            "이거 LLM 모델이 되게 잘하거든"
        )
        XCTAssertLessThan(ratio, 0.5, "Korean syllable corrections should be under 50% word-level change")
    }

    // MARK: - NoneProvider

    func testNoneProviderReturnsOriginal() async throws {
        let provider = NoneProvider()
        XCTAssertTrue(provider.isReady)
        XCTAssertFalse(provider.requiresNetwork)

        let result = try await provider.correct(text: "원문 텍스트", systemPrompt: "any prompt", glossary: nil)
        XCTAssertEqual(result, "원문 텍스트")
    }

    func testNoneProviderWithGlossary() async throws {
        let provider = NoneProvider()
        let result = try await provider.correct(text: "test", systemPrompt: "prompt", glossary: ["API", "React"])
        XCTAssertEqual(result, "test", "NoneProvider should ignore glossary and return original")
    }
}
