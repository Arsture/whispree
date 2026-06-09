import Foundation

/// Groq Cloud LLM Provider.
///
/// Chat Completions API (`https://api.groq.com/openai/v1/chat/completions`)는 OpenAI 호환 포맷.
/// Vision은 `meta-llama/llama-4-scout-17b-16e-instruct`만 지원하며,
/// `supportsVision`은 선택된 모델에 따라 동적으로 결정된다.
@MainActor
final class GroqLLMProvider: LLMProvider {
    let name = "Groq Cloud"
    let requiresNetwork = true
    var supportsVision: Bool { model.supportsVision }

    private let apiKey: String
    private var model: GroqLLMModel
    private let correctionTimeout: TimeInterval = 20.0

    init(model: GroqLLMModel, apiKey: String) {
        self.model = model
        self.apiKey = apiKey
    }

    func validate() -> ProviderValidation {
        apiKey.isEmpty
            ? .invalid("Groq API Key가 필요합니다. STT 설정 또는 LLM 설정에서 입력하세요.")
            : .valid
    }

    func setup() async throws {}
    func teardown() async {}

    func updateModel(_ newModel: GroqLLMModel) {
        model = newModel
    }

    func correct(
        text: String,
        systemPrompt: String,
        glossary: [String]?,
        screenshots: [Data] = []
    ) async throws -> String {
        guard !apiKey.isEmpty else {
            throw LLMError.correctionFailed("Groq API Key가 비어있습니다.")
        }

        var fullPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        // user content 빌드 — vision 모델만 image 블록 포함
        let userContent: Any
        if supportsVision, !screenshots.isEmpty {
            let recent = screenshots.suffix(3)
            var parts: [[String: Any]] = []
            for shot in recent {
                let b64 = shot.base64EncodedString()
                parts.append([
                    "type": "image_url",
                    "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
                ])
            }
            parts.append(["type": "text", "text": text])
            userContent = parts
        } else {
            userContent = text
        }

        var body: [String: Any] = [
            "model": model.rawValue,
            "messages": [
                ["role": "system", "content": fullPrompt],
                ["role": "user", "content": userContent]
            ],
            "temperature": 0,
            "max_completion_tokens": 2048,
            "stream": false
        ]

        // 모델 family별 reasoning 처리.
        // - Qwen3: reasoning_effort=none + reasoning_format=hidden → 추론 완전 비활성, content에 <think> 누락 안 됨
        // - GPT-OSS: reasoning_format 미지원, reasoning_effort=low 만 적용 → reasoning은 별도 `reasoning` 필드로 옴 (무시)
        // - 그 외(Llama 등): 추론 모델 아님, 파라미터 미설정
        let rawId = model.rawValue
        if rawId.hasPrefix("qwen/") {
            body["reasoning_effort"] = "none"
            body["reasoning_format"] = "hidden"
        } else if rawId.hasPrefix("openai/gpt-oss") {
            body["reasoning_effort"] = "low"
        }

        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = correctionTimeout
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let result = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { try await Self.performRequest(request) }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.correctionTimeout * 1_000_000_000))
                throw LLMError.timeout
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }

        let trimmed = Self.stripThinkBlock(result).trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = Self.removeCodeFences(trimmed)
        if cleaned.isEmpty { return text }

        // word-edit-distance 안전장치 — LLM 환각 시 원문 반환
        let changeRatio = LocalTextProvider.wordEditDistance(text, cleaned)
        if changeRatio > 0.5 { return text }

        return cleaned
    }

    // MARK: - Networking

    private static func performRequest(_ request: URLRequest) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.correctionFailed("Groq 응답 없음")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw LLMError.correctionFailed("Groq API \(http.statusCode): \(body)")
        }

        struct GroqResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String?
                }
                let message: Message
            }
            let choices: [Choice]
        }

        let decoded = try JSONDecoder().decode(GroqResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    // MARK: - Utilities

    /// Qwen3 등의 `<think>...</think>` 블록 제거.
    private static func stripThinkBlock(_ text: String) -> String {
        if let end = text.range(of: "</think>") {
            return String(text[end.upperBound...])
        }
        if text.hasPrefix("<think>") {
            return ""
        }
        return text
    }

    /// 마크다운 코드 펜스 (```...```) 제거.
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
