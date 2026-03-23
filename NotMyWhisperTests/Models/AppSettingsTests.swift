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
        XCTAssertEqual(STTProviderType.allCases.count, 3)
        XCTAssertEqual(STTProviderType.whisperKit.rawValue, "WhisperKit")
        XCTAssertEqual(STTProviderType.groq.rawValue, "Groq")
        XCTAssertEqual(STTProviderType.mlxAudio.rawValue, "MLX Audio")
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

    // MARK: - New Correction Modes

    func testCorrectionModeFillerRemoval() {
        XCTAssertEqual(CorrectionMode.fillerRemoval.rawValue, "fillerRemoval")
        XCTAssertFalse(CorrectionMode.fillerRemoval.displayName.isEmpty)
        XCTAssertFalse(CorrectionMode.fillerRemoval.description.isEmpty)
    }

    func testCorrectionModeStructured() {
        XCTAssertEqual(CorrectionMode.structured.rawValue, "structured")
        XCTAssertFalse(CorrectionMode.structured.displayName.isEmpty)
        XCTAssertFalse(CorrectionMode.structured.description.isEmpty)
    }

    func testCorrectionModeCount() {
        XCTAssertEqual(CorrectionMode.allCases.count, 4,
                       "Should have standard, fillerRemoval, structured, custom")
    }

    func testPromptRoutingFillerRemoval() {
        let prompt = CorrectionPrompts.prompt(for: .fillerRemoval, language: .auto)
        XCTAssertTrue(prompt.contains("필러"),
                      "Filler removal mode should mention fillers")
        XCTAssertTrue(prompt.contains("문장 순서 변경 금지"),
                      "Filler removal should preserve sentence order")
    }

    func testPromptRoutingStructured() {
        let prompt = CorrectionPrompts.prompt(for: .structured, language: .auto)
        XCTAssertTrue(prompt.contains("구조화"),
                      "Structured mode should mention structuring")
        XCTAssertTrue(prompt.contains("절대 삭제하지 않음"),
                      "Structured mode should preserve content")
    }

    func testPromptEngineeringMigration() throws {
        // Simulate old "promptEngineering" value stored in JSON
        let json = #"{"correctionMode":"promptEngineering"}"#
        let data = json.data(using: .utf8)!

        struct TestWrapper: Codable {
            var correctionMode: CorrectionMode
        }

        let decoded = try JSONDecoder().decode(TestWrapper.self, from: data)
        XCTAssertEqual(decoded.correctionMode, .fillerRemoval,
                       "Old promptEngineering should migrate to fillerRemoval")
    }
}
