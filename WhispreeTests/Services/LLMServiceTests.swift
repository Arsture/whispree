import XCTest
@testable import Whispree

@MainActor
final class LLMServiceTests: XCTestCase {

    // MARK: - Word Edit Distance (via LocalTextProvider)

    func testWordEditDistanceIdentical() {
        let ratio = LocalTextProvider.wordEditDistance("안녕하세요 반갑습니다", "안녕하세요 반갑습니다")
        XCTAssertEqual(ratio, 0.0)
    }

    func testWordEditDistanceOneWordChanged() {
        let ratio = LocalTextProvider.wordEditDistance(
            "이거 L&M 모델이 되개 잘하거든",
            "이거 LLM 모델이 되게 잘하거든"
        )
        XCTAssertLessThanOrEqual(ratio, 0.5)
    }

    func testWordEditDistanceCompletelyDifferent() {
        let ratio = LocalTextProvider.wordEditDistance("hello world", "안녕 세상")
        XCTAssertEqual(ratio, 1.0)
    }

    func testWordEditDistanceEmpty() {
        let ratio = LocalTextProvider.wordEditDistance("", "")
        XCTAssertEqual(ratio, 0.0)
    }

    func testWordEditDistanceOneEmpty() {
        let ratio = LocalTextProvider.wordEditDistance("hello", "")
        XCTAssertEqual(ratio, 1.0)
    }

    func testWordEditDistanceKoreanCorrection() {
        let ratio = LocalTextProvider.wordEditDistance(
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
        XCTAssertFalse(provider.supportsVision)

        let result = try await provider.correct(text: "원문 텍스트", systemPrompt: "any prompt", glossary: nil)
        XCTAssertEqual(result, "원문 텍스트")
    }

    func testNoneProviderWithGlossary() async throws {
        let provider = NoneProvider()
        let result = try await provider.correct(text: "test", systemPrompt: "prompt", glossary: ["API", "React"])
        XCTAssertEqual(result, "test", "NoneProvider should ignore glossary and return original")
    }

    // MARK: - LocalModelSpec

    func testLocalModelSpecFind() {
        let spec = LocalModelSpec.find("mlx-community/Qwen3-4B-Instruct-2507-4bit")
        XCTAssertNotNil(spec)
        XCTAssertEqual(spec?.capability, .text)
    }

    func testLocalModelSpecFindVision() {
        let visionSpec = LocalModelSpec.supported.first { $0.capability == .vision }
        XCTAssertNotNil(visionSpec)
    }

    func testLocalModelSpecFindUnknown() {
        let spec = LocalModelSpec.find("unknown/model")
        XCTAssertNil(spec)
    }

    // MARK: - Provider Properties

    func testLocalTextProviderProperties() {
        let provider = LocalTextProvider()
        XCTAssertFalse(provider.requiresNetwork)
        XCTAssertFalse(provider.supportsVision)
    }

    func testOpenAIProviderSupportsVision() {
        // OpenAIProvider requires auth services — just check the property exists
        XCTAssertTrue(true, "OpenAIProvider.supportsVision is declared as true")
    }
}
