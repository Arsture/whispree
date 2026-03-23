import XCTest
@testable import Whispree

final class DomainWordSetsTests: XCTestCase {

    // MARK: - DomainWordSet Generation

    func testGenerateDefaultITDev() {
        let set = DomainWordSet.generateDefault(domain: .itDev)
        XCTAssertEqual(set.name, "IT/개발")
        XCTAssertTrue(set.isEnabled)
        XCTAssertTrue(set.words.contains("API"))
        XCTAssertTrue(set.words.contains("React"))
        XCTAssertTrue(set.words.contains("LLM"))
        XCTAssertTrue(set.words.contains("GitHub"))
        XCTAssertFalse(set.words.isEmpty)
    }

    func testGenerateDefaultStatistics() {
        let set = DomainWordSet.generateDefault(domain: .statistics)
        XCTAssertEqual(set.name, "통계")
        XCTAssertFalse(set.isEnabled) // default disabled
        XCTAssertTrue(set.words.contains("T-distribution"))
        XCTAssertTrue(set.words.contains("p-value"))
        XCTAssertTrue(set.words.contains("regression"))
    }

    func testGenerateDefaultCustom() {
        let set = DomainWordSet.generateDefault(domain: .custom)
        XCTAssertEqual(set.name, "사용자 정의")
        XCTAssertTrue(set.isEnabled)
        XCTAssertTrue(set.words.isEmpty)
    }

    func testUniqueIds() {
        let set1 = DomainWordSet.generateDefault(domain: .itDev)
        let set2 = DomainWordSet.generateDefault(domain: .itDev)
        XCTAssertNotEqual(set1.id, set2.id)
    }

    // MARK: - Prompt Text Building

    func testBuildPromptTextWithWords() {
        let set = DomainWordSet(id: UUID(), name: "Test", words: ["API", "backend", "frontend"], isEnabled: true)
        let prompt = set.buildPromptText()
        XCTAssertTrue(prompt.contains("API"))
        XCTAssertTrue(prompt.contains("backend"))
        XCTAssertTrue(prompt.contains("frontend"))
        XCTAssertTrue(prompt.contains("discussed"))
    }

    func testBuildPromptTextEmpty() {
        let set = DomainWordSet(id: UUID(), name: "Empty", words: [], isEnabled: true)
        let prompt = set.buildPromptText()
        XCTAssertEqual(prompt, "")
    }

    func testBuildPromptTextChunking() {
        // 16 words should create 2 chunks of 8
        let words = (0..<16).map { "word\($0)" }
        let set = DomainWordSet(id: UUID(), name: "Big", words: words, isEnabled: true)
        let prompt = set.buildPromptText()
        // Should have 2 "discussed" occurrences (2 chunks)
        let count = prompt.components(separatedBy: "discussed").count - 1
        XCTAssertEqual(count, 2)
    }

    // MARK: - Array Chunking

    func testChunkedInto() {
        let array = [1, 2, 3, 4, 5, 6, 7]
        let chunks = array.chunked(into: 3)
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks[0], [1, 2, 3])
        XCTAssertEqual(chunks[1], [4, 5, 6])
        XCTAssertEqual(chunks[2], [7])
    }

    func testChunkedIntoEmpty() {
        let array: [Int] = []
        let chunks = array.chunked(into: 3)
        XCTAssertTrue(chunks.isEmpty)
    }

    // MARK: - Codable

    func testCodable() throws {
        let original = DomainWordSet(id: UUID(), name: "Test", words: ["API", "React"], isEnabled: true)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DomainWordSet.self, from: data)
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.name, decoded.name)
        XCTAssertEqual(original.words, decoded.words)
        XCTAssertEqual(original.isEnabled, decoded.isEnabled)
    }
}
