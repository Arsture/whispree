import Foundation

@MainActor
final class ClaudeLLMProvider: LLMProvider {
    let name = "Claude (Anthropic)"
    let requiresNetwork = true
    let supportsVision = true

    private let model: ClaudeModel
    private let apiKey: String

    init(model: ClaudeModel = .haiku45, apiKey: String) {
        self.model = model
        self.apiKey = apiKey
    }

    func validate() -> ProviderValidation {
        apiKey.isEmpty ? .invalid("Anthropic API Key가 필요합니다") : .valid
    }

    func setup() async throws {}

    func teardown() async {}

    func correct(text: String, systemPrompt: String, glossary: [String]?, screenshots: [Data] = []) async throws -> String {
        var fullPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        // 스크린샷이 있으면 Vision 멀티모달, 없으면 텍스트 전용
        let userContent: Any
        let recentScreenshots = screenshots.suffix(5)
        if recentScreenshots.isEmpty {
            userContent = text
        } else {
            var blocks: [[String: Any]] = []
            for screenshotData in recentScreenshots {
                let base64Image = screenshotData.base64EncodedString()
                blocks.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64Image
                    ] as [String: Any]
                ])
            }
            blocks.append(["type": "text", "text": text])
            userContent = blocks
        }

        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 2000,
            "system": fullPrompt,
            "messages": [
                ["role": "user", "content": userContent]
            ],
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let result = try await parseSSEStream(request: request, originalText: text)

        if result == text { return result }

        // 안전장치: 출력이 입력보다 2.5배 이상 길면 답변 생성으로 판단
        let inputWords = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        let outputWords = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        if inputWords > 0, Double(outputWords) / Double(inputWords) > 2.5 { return text }

        // word-edit-distance 안전장치 (threshold 0.5)
        let changeRatio = LocalTextProvider.wordEditDistance(text, result)
        if changeRatio > 0.5 { return text }

        return result
    }

    // MARK: - SSE Streaming

    private func parseSSEStream(request: URLRequest, originalText: String) async throws -> String {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return originalText
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw LLMError.correctionFailed("인증 실패. API Key를 확인해주세요.")
        case 429:
            throw LLMError.correctionFailed("요청 제한 초과. 잠시 후 다시 시도해주세요.")
        case 529:
            throw LLMError.correctionFailed("API 과부하. 잠시 후 다시 시도해주세요.")
        default:
            throw LLMError.correctionFailed("API 오류 (HTTP \(httpResponse.statusCode))")
        }

        var result = ""

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String
            else { continue }

            if type == "content_block_delta",
               let delta = json["delta"] as? [String: Any],
               let deltaType = delta["type"] as? String,
               deltaType == "text_delta",
               let textChunk = delta["text"] as? String {
                result += textChunk
            } else if type == "message_stop" {
                break
            }
        }

        var trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // <think>...</think> 블록 제거
        if let thinkEnd = trimmed.range(of: "</think>") {
            trimmed = String(trimmed[thinkEnd.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if trimmed.hasPrefix("<think>") {
            trimmed = ""
        }

        let cleaned = Self.removeCodeFences(trimmed)
        return cleaned.isEmpty ? originalText : cleaned
    }

    // MARK: - Utilities

    private static func removeCodeFences(_ text: String) -> String {
        var result = text
        if result.hasPrefix("```") {
            if let firstNewline = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: firstNewline)...])
            }
        }
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateModel(_ newModel: ClaudeModel) -> ClaudeLLMProvider {
        ClaudeLLMProvider(model: newModel, apiKey: apiKey)
    }
}
