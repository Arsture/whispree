import Foundation
import MLXVLM
import MLXLMCommon

@MainActor
final class LocalVisionProvider: LLMProvider {
    let name = "로컬 VLM"
    let requiresNetwork = false
    let supportsVision = true

    private var modelContainer: ModelContainer?
    private let modelId: String
    private let correctionTimeout: TimeInterval = 30.0

    func validate() -> ProviderValidation {
        modelContainer != nil ? .valid : .invalid("로컬 VLM 모델이 로드되지 않았습니다. 모델을 다운로드해주세요.")
    }

    init(modelId: String) {
        self.modelId = modelId
    }

    func setup() async throws {
        let config = ModelConfiguration(id: modelId)
        modelContainer = try await VLMModelFactory.shared.loadContainer(configuration: config) { _ in }
    }

    func teardown() async {
        modelContainer = nil
    }

    func correct(text: String, systemPrompt: String, glossary: [String]?, screenshots: [Data] = []) async throws -> String {
        guard let modelContainer else { throw LLMError.modelNotLoaded }

        var fullPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        // 스크린샷을 base64 이미지 URL로 변환 (최근 3장)
        let recentScreenshots = screenshots.suffix(3)
        var userContent: [Any] = []
        for screenshotData in recentScreenshots {
            let base64 = screenshotData.base64EncodedString()
            userContent.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]])
        }
        userContent.append(["type": "text", "text": text])

        let messages: [[String: Any]] = [
            ["role": "system", "content": fullPrompt],
            ["role": "user", "content": userContent]
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
                        if tokens.count > 500 { return .stop }
                        return .more
                    }
                }
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

        let changeRatio = LocalTextProvider.wordEditDistance(text, result)
        if changeRatio > 0.5 { return text }

        return result
    }
}
