import Foundation

/// OpenAI Chat Completions API 호환 클라우드 LLM 프로바이더
/// OpenAI / Groq / Gemini / DeepSeek / xAI / OpenRouter를 base URL 전환으로 지원
@MainActor
final class CloudLLMProvider: LLMProvider {
    let name: String
    let requiresNetwork = true
    let supportsVision: Bool

    private let service: CloudLLMService
    private let modelId: String
    private let apiKey: String

    init(service: CloudLLMService, modelId: String, apiKey: String) {
        self.service = service
        self.modelId = modelId
        self.apiKey = apiKey
        self.name = service.displayName
        self.supportsVision = service.supportsVision(modelId: modelId)
    }

    func validate() -> ProviderValidation {
        apiKey.isEmpty ? .invalid("API Key가 필요합니다.") : .valid
    }

    func setup() async throws {
        // 네트워크 프로바이더이므로 특별한 초기화 불필요
    }

    func teardown() async {
        // 네트워크 프로바이더이므로 특별한 해제 불필요
    }

    func correct(text: String, systemPrompt: String, glossary: [String]?, screenshots: [Data] = []) async throws -> String {
        // glossary를 시스템 프롬프트에 주입
        var fullPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        let url = URL(string: "\(service.baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // OpenRouter 전용 헤더
        if service == .openrouter {
            request.setValue("https://whispree.app", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Whispree", forHTTPHeaderField: "X-Title")
        }

        // Vision 지원 + 스크린샷 있으면 멀티모달 content, 없으면 텍스트 전용
        let userContent: Any
        let hasScreenshots = !screenshots.isEmpty && supportsVision
        if hasScreenshots {
            var contentArray: [[String: Any]] = []
            for screenshotData in screenshots.suffix(3) {
                let base64Image = screenshotData.base64EncodedString()
                contentArray.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]
                ])
            }
            contentArray.append(["type": "text", "text": text])
            userContent = contentArray
        } else {
            userContent = text
        }

        let body: [String: Any] = [
            "model": modelId,
            "messages": [
                ["role": "system", "content": fullPrompt],
                ["role": "user", "content": userContent]
            ],
            "stream": true,
            "temperature": 0,
            "max_tokens": 2000
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let result = try await parseSSEStream(request: request, originalText: text)

        // 안전장치: 출력이 입력보다 2.5배 이상 길면 답변 생성으로 판단
        if result == text { return result }
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
        default:
            throw LLMError.correctionFailed("API 오류 (HTTP \(httpResponse.statusCode))")
        }

        var result = ""

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard jsonStr != "[DONE]" else { break }

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String
            else { continue }

            result += content
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
