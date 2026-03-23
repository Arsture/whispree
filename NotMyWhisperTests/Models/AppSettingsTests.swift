import XCTest
@testable import NotMyWhisper

final class AppSettingsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 테스트 전 UserDefaults 초기화 (캐시된 설정 제거)
        UserDefaults.standard.removeObject(forKey: "NotMyWhisperSettings")
    }

    // MARK: - Default Values

    func testDefaultSTTProvider() {
        let settings = AppSettings()
        XCTAssertEqual(settings.sttProviderType, .whisperKit)
    }

    func testDefaultLLMProvider() {
        let settings = AppSettings()
        XCTAssertEqual(settings.llmProviderType, .none)
    }

    func testDefaultOpenAIModel() {
        let settings = AppSettings()
        XCTAssertEqual(settings.openaiModel, .gpt54)
    }

    func testDefaultLLMDisabled() {
        let settings = AppSettings()
        XCTAssertFalse(settings.isLLMEnabled, "LLM should be disabled by default")
    }

    func testDefaultDomainWordSetsEmpty() {
        let settings = AppSettings()
        XCTAssertTrue(settings.domainWordSets.isEmpty)
    }

    // MARK: - Provider Types

    func testSTTProviderTypeCases() {
        XCTAssertEqual(STTProviderType.allCases.count, 2)
        XCTAssertEqual(STTProviderType.whisperKit.rawValue, "WhisperKit")
        XCTAssertEqual(STTProviderType.lightning.rawValue, "Lightning-SimulWhisper")
    }

    func testLLMProviderTypeCases() {
        XCTAssertEqual(LLMProviderType.allCases.count, 3)
        XCTAssertEqual(LLMProviderType.none.rawValue, "없음 (원문 사용)")
        XCTAssertEqual(LLMProviderType.local.rawValue, "로컬 LLM (Qwen3)")
        XCTAssertEqual(LLMProviderType.openai.rawValue, "OpenAI (GPT)")
    }

    // MARK: - OpenAI Models

    func testOpenAIModelDefaults() {
        XCTAssertEqual(OpenAIModel.gpt54.rawValue, "gpt-5.4")
        XCTAssertEqual(OpenAIModel.gpt54mini.rawValue, "gpt-5.4-mini")
        XCTAssertEqual(OpenAIModel.gpt53codex.rawValue, "gpt-5.3-codex")
    }

    func testOpenAIModelDisplayNames() {
        XCTAssertTrue(OpenAIModel.gpt54.displayName.contains("Best"))
        XCTAssertTrue(OpenAIModel.gpt54mini.displayName.contains("Fast"))
    }

    // MARK: - CorrectionPrompts Routing

    func testPromptRoutingAutoUsesCodeSwitch() {
        let prompt = CorrectionPrompts.prompt(for: .standard, language: .auto)
        XCTAssertTrue(prompt.contains("코드스위칭") || prompt.contains("영어 단어"),
                      "Auto mode should use code-switching prompt")
    }

    func testPromptRoutingKorean() {
        let prompt = CorrectionPrompts.prompt(for: .standard, language: .korean)
        XCTAssertTrue(prompt.contains("한국어") || prompt.contains("STT"),
                      "Korean mode should use Korean-language prompt")
    }

    func testPromptRoutingCustomUsesCodeSwitch() {
        let prompt = CorrectionPrompts.prompt(for: .custom, language: .auto)
        XCTAssertTrue(prompt.contains("코드스위칭") || prompt.contains("영어 단어"),
                      "Custom mode should default to code-switching prompt")
    }

    func testCodeSwitchPromptContainsExamples() {
        let prompt = CorrectionPrompts.codeSwitchPrompt
        XCTAssertTrue(prompt.contains("validation"))
        XCTAssertTrue(prompt.contains("React"))
        XCTAssertTrue(prompt.contains("GitHub"))
        XCTAssertTrue(prompt.contains("T-distribution"))
    }
}
