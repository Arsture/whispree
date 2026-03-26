import Combine
import Foundation
import MLXLLM
import MLXLMCommon

@MainActor
final class LLMService: ObservableObject {
    @Published var modelState: ModelState = .notDownloaded

    private var modelContainer: ModelContainer?
    private let correctionTimeout: TimeInterval = 5.0

    func loadModel(modelId: String = "mlx-community/Qwen3-4B-Instruct-2507-4bit") async throws {
        modelState = .loading

        do {
            let config = ModelConfiguration(id: modelId)
            modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config) { progress in
                Task { @MainActor in
                    self.modelState = .downloading(progress: progress.fractionCompleted)
                }
            }
            modelState = .ready
        } catch {
            modelState = .error(error.localizedDescription)
            throw error
        }
    }

    func correct(text: String, customPrompt: String? = nil) async throws -> String {
        guard let modelContainer else {
            throw LLMError.modelNotLoaded
        }

        let systemPrompt = customPrompt ?? CorrectionPrompts.defaultSystemPrompt
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": text]
        ]

        let result = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let output = try await modelContainer.perform { context in
                    let input = try await context.processor.prepare(input: .init(messages: messages))
                    let params = GenerateParameters(
                        temperature: 0, // greedy decoding - most deterministic
                        topP: 1.0,
                        repetitionPenalty: 1.2 // discourage hallucinated repetitions
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

        // Safety: if LLM changed too much, it's hallucinating — use original
        let changeRatio = Self.wordEditDistance(text, result)
        if changeRatio > 0.5 { // 단어 기준 50% 이상 변경 시 reject (기존 0.4에서 완화)
            return text
        }

        return result
    }

    /// 단어 단위 편집 거리 비율 (0.0 ~ 1.0)
    /// 한국어 음절 블록에서 문자 단위 Levenshtein은 false negative를 유발함
    /// 예: "프람프트" → "프롬프트"는 문자 80% 변경이지만 단어 1개 변경
    /// Test-accessible wrapper
    static func testWordEditDistance(_ a: String, _ b: String) -> Double {
        wordEditDistance(a, b)
    }

    private static func wordEditDistance(_ a: String, _ b: String) -> Double {
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

    var isReady: Bool {
        modelContainer != nil && modelState == .ready
    }

    func unloadModel() {
        modelContainer = nil
        modelState = .notDownloaded
    }
}

enum LLMError: LocalizedError {
    case modelNotLoaded
    case correctionFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
            case .modelNotLoaded: "LLM model is not loaded"
            case let .correctionFailed(msg): "Text correction failed: \(msg)"
            case .timeout: "Text correction timed out"
        }
    }
}
