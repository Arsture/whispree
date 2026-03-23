import Foundation
import MLXLLM
import MLXLMCommon

@MainActor
final class LocalLLMProvider: LLMProvider {
    let name = "로컬 LLM (Qwen3)"
    let requiresNetwork = false

    private var modelContainer: ModelContainer?
    private let modelId: String
    private let correctionTimeout: TimeInterval = 5.0

    var isReady: Bool { modelContainer != nil }

    init(modelId: String = "mlx-community/Qwen3-4B-Instruct-2507-4bit") {
        self.modelId = modelId
    }

    func setup() async throws {
        let config = ModelConfiguration(id: modelId)
        modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config) { _ in }
    }

    func teardown() async {
        modelContainer = nil
    }

    func correct(text: String, systemPrompt: String, glossary: [String]?) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        // glossary를 시스템 프롬프트에 주입
        var fullPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": fullPrompt],
            ["role": "user", "content": text]
        ]

        let result = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let output = try await modelContainer.perform { context in
                    let input = try await context.processor.prepare(input: .init(messages: messages))
                    let params = GenerateParameters(
                        temperature: 0,
                        topP: 1.0,
                        repetitionPenalty: 1.2
                    )
                    return try MLXLMCommon.generate(input: input, parameters: params, context: context) { tokens in
                        if tokens.count > 200 { return .stop }
                        return .more
                    }
                }
                return output.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.correctionTimeout * 1_000_000_000))
                throw LLMError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        if result.isEmpty { return text }

        // 단어 단위 안전장치: 50% 이상 변경 시 원본 반환
        let changeRatio = Self.wordEditDistance(text, result)
        if changeRatio > 0.5 { return text }

        return result
    }

    /// 단어 단위 편집 거리 비율 (0.0 ~ 1.0)
    private static func wordEditDistance(_ a: String, _ b: String) -> Double {
        let wordsA = a.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let wordsB = b.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !wordsA.isEmpty else { return wordsB.isEmpty ? 0 : 1 }
        guard !wordsB.isEmpty else { return 1 }
        var dp = Array(0...wordsB.count)
        for i in 1...wordsA.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1...wordsB.count {
                let temp = dp[j]
                if wordsA[i - 1] == wordsB[j - 1] {
                    dp[j] = prev
                } else {
                    dp[j] = min(prev, dp[j], dp[j - 1]) + 1
                }
                prev = temp
            }
        }
        return Double(dp[wordsB.count]) / Double(max(wordsA.count, wordsB.count))
    }
}
