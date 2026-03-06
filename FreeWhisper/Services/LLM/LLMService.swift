import Foundation
import MLXLLM
import MLXLMCommon
import Combine

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
                        temperature: 0,       // greedy decoding - most deterministic
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
        let changeRatio = Double(Self.editDistance(text, result)) / Double(max(1, text.count))
        if changeRatio > 0.4 {
            return text
        }

        return result
    }

    /// Levenshtein edit distance (character-level)
    private static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a)
        let b = Array(b)
        var dp = Array(0...b.count)
        for i in 1...max(a.count, 1) {
            guard i <= a.count else { break }
            var prev = dp[0]
            dp[0] = i
            for j in 1...b.count {
                let temp = dp[j]
                if a[i - 1] == b[j - 1] {
                    dp[j] = prev
                } else {
                    dp[j] = min(prev, dp[j], dp[j - 1]) + 1
                }
                prev = temp
            }
        }
        return dp[b.count]
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
        case .modelNotLoaded: return "LLM model is not loaded"
        case .correctionFailed(let msg): return "Text correction failed: \(msg)"
        case .timeout: return "Text correction timed out"
        }
    }
}
