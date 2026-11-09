@testable import Whispree
import XCTest

final class CodexModelCatalogTests: XCTestCase {
    private let sampleJSON = #"""
    {
      "fetched_at": "2026-11-09T14:22:00Z",
      "etag": "W/\"abc\"",
      "client_version": "0.167.0",
      "models": [
        {"slug": "gpt-b", "display_name": "GPT-B", "visibility": "list", "supported_in_api": true, "priority": 2,
         "description": "b model",
         "supported_reasoning_levels": [{"effort": "medium", "description": "m"}, {"effort": "low", "description": "l"}, {"effort": "high"}],
         "input_modalities": ["text", "image"], "context_window": 400000, "shell_type": "x"},
        {"slug": "gpt-hidden", "display_name": "Hidden", "visibility": "hide", "supported_in_api": true, "priority": 0},
        {"slug": "gpt-no-api", "display_name": "NoAPI", "visibility": "list", "supported_in_api": false, "priority": 0},
        {"slug": "gpt-a", "display_name": "GPT-A", "visibility": "list", "priority": 1,
         "supported_reasoning_levels": [{"effort": "minimal"}, {"effort": "low"}],
         "input_modalities": ["text"]},
        {"slug": "gpt-c", "visibility": "list", "priority": "not-a-number"},
        "garbage entry"
      ]
    }
    """#

    func testDecodeFiltersSortsAndMapsFields() throws {
        let models = try XCTUnwrap(CodexModelCatalog.decode(Data(sampleJSON.utf8)))

        XCTAssertEqual(models.map(\.slug), ["gpt-a", "gpt-b", "gpt-c"])

        let a = models[0]
        XCTAssertEqual(a.displayName, "GPT-A")
        XCTAssertFalse(a.supportsVision)
        XCTAssertEqual(a.supportedEfforts, ["minimal", "low"])
        XCTAssertEqual(a.lowestEffort, "minimal")

        let b = models[1]
        XCTAssertEqual(b.description, "b model")
        XCTAssertTrue(b.supportsVision)
        XCTAssertEqual(b.lowestEffort, "low")

        // 누락/깨진 필드는 관대하게: display_name 없으면 slug, efforts 없으면 빈 배열
        let c = models[2]
        XCTAssertEqual(c.displayName, "gpt-c")
        XCTAssertEqual(c.supportedEfforts, [])
        XCTAssertNil(c.lowestEffort)
    }

    func testDecodeInvalidDataReturnsNil() {
        XCTAssertNil(CodexModelCatalog.decode(Data("not json".utf8)))
        XCTAssertNil(CodexModelCatalog.decode(Data(#"{"models": "nope"}"#.utf8)))
        XCTAssertNil(CodexModelCatalog.decode(Data(#"{"models": []}"#.utf8)))
        XCTAssertNil(CodexModelCatalog.decode(Data(#"{"models": [{"slug": "x", "visibility": "hide"}]}"#.utf8)))
    }

    func testLoadFallsBackWhenFileMissingOrInvalid() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let missing = dir.appendingPathComponent("missing.json")
        XCTAssertEqual(CodexModelCatalog.load(from: missing), CodexModelCatalog.fallbackModels)

        let invalid = dir.appendingPathComponent("invalid.json")
        try Data("{".utf8).write(to: invalid)
        XCTAssertEqual(CodexModelCatalog.load(from: invalid), CodexModelCatalog.fallbackModels)

        let valid = dir.appendingPathComponent("valid.json")
        try Data(sampleJSON.utf8).write(to: valid)
        XCTAssertEqual(CodexModelCatalog.load(from: valid).map(\.slug), ["gpt-a", "gpt-b", "gpt-c"])
    }

    func testFallbackListAndDefault() {
        XCTAssertEqual(CodexModelCatalog.fallbackModels.map(\.slug), [
            "gpt-6.1-sol", "gpt-6.1-terra", "gpt-6-astra", "gpt-6-sol",
            "gpt-6-luna", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna",
        ])
        XCTAssertTrue(CodexModelCatalog.fallbackModels.contains { $0.slug == CodexModelCatalog.defaultModelSlug })
        // fallback은 effort를 모르므로 reasoning 필드를 생략하게 된다
        XCTAssertTrue(CodexModelCatalog.fallbackModels.allSatisfy { $0.lowestEffort == nil })
    }

    func testLowestEffortOrdering() {
        XCTAssertEqual(CodexModelCatalog.lowestEffort(in: ["high", "low", "medium"]), "low")
        XCTAssertEqual(CodexModelCatalog.lowestEffort(in: ["ultra", "max", "xhigh"]), "xhigh")
        XCTAssertEqual(CodexModelCatalog.lowestEffort(in: ["medium", "none"]), "none")
        XCTAssertNil(CodexModelCatalog.lowestEffort(in: []))
        XCTAssertNil(CodexModelCatalog.lowestEffort(in: ["turbo"]))
    }

    func testNormalizedSlugAliases() {
        XCTAssertEqual(CodexModelCatalog.normalizedSlug("gpt-5.6"), "gpt-5.6-sol")
        XCTAssertEqual(CodexModelCatalog.normalizedSlug("gpt-5.3-codex-spark"), "gpt-5.4-mini")
        XCTAssertEqual(CodexModelCatalog.normalizedSlug("gpt-5.2-codex"), "gpt-5.2")
        XCTAssertEqual(CodexModelCatalog.normalizedSlug("gpt-6-luna"), "gpt-6-luna")
    }
}
