import Foundation
import MLXLLM
import MLXLMCommon

@MainActor
final class LocalTextProvider: LLMProvider {
    let name = "로컬 LLM"
    let requiresNetwork = false
    let supportsVision = false

    private var modelContainer: ModelContainer?
    private let modelId: String
    private let correctionTimeout: TimeInterval = 15.0

    func validate() -> ProviderValidation {
        modelContainer != nil ? .valid : .invalid("로컬 LLM 모델이 로드되지 않았습니다. 모델을 다운로드해주세요.")
    }

    init(modelId: String = LocalModelSpec.defaultModelId) {
        self.modelId = modelId
    }

    func setup() async throws {
        let config = ModelConfiguration(id: modelId)
        modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config) { _ in }
    }

    func teardown() async {
        modelContainer = nil
    }

    func correct(text: String, systemPrompt: String, glossary: [String]?, screenshots: [Data] = []) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        var fullPrompt = systemPrompt + "\n/no_think"
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
                        if tokens.count > 2000 { return .stop }
                        return .more
                    }
                }
                // Strip Qwen3 <think>...</think> blocks
                var text = output.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if let thinkEnd = text.range(of: "</think>") {
                    text = String(text[thinkEnd.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                } else if text.hasPrefix("<think>") {
                    return ""
                }
                return text
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

        let changeRatio = Self.wordEditDistance(text, result)
        if changeRatio > 0.5 { return text }

        return result
    }

    // MARK: - Word Edit Distance

    /// 단어 단위 편집 거리 비율 (0.0 ~ 1.0)
    static func wordEditDistance(_ a: String, _ b: String) -> Double {
        let wordsA = a.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let wordsB = b.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !wordsA.isEmpty else { return wordsB.isEmpty ? 0 : 1 }
        guard !wordsB.isEmpty else { return 1 }
        var dp = Array(0 ... wordsB.count)
        for i in 1 ... wordsA.count {
            var prev = dp[0]
            dp[0] = i
            for j in 1 ... wordsB.count {
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
