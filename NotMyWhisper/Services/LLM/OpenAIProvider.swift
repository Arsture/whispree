import Foundation

@MainActor
final class OpenAIProvider: LLMProvider {
    let name = "OpenAI (GPT)"
    let requiresNetwork = true

    private let authService: CodexAuthService
    private var model: OpenAIModel

    var isReady: Bool { authService.isLoggedIn }

    init(model: OpenAIModel = .gpt54, authService: CodexAuthService) {
        self.model = model
        self.authService = authService
    }

    func setup() async throws {
        authService.checkAuth()
        if !authService.isLoggedIn {
            throw AuthError.notAuthenticated
        }
    }

    func teardown() async {
        // 네트워크 Provider는 특별한 해제 불필요
    }

    func correct(text: String, systemPrompt: String, glossary: [String]?) async throws -> String {
        guard let tokens = authService.loadTokens() else {
            throw AuthError.notAuthenticated
        }

        // glossary를 시스템 프롬프트에 동적 주입
        var fullPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        // ChatGPT Responses API 요청 구성
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/codex/responses")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(tokens.access_token)", forHTTPHeaderField: "Authorization")
        request.setValue(tokens.account_id, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(Self.buildUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")

        let body: [String: Any] = [
            "model": model.rawValue,
            "instructions": fullPrompt,
            "input": [
                ["type": "message", "role": "user",
                 "content": [["type": "input_text", "text": text]]]
            ],
            "tools": [] as [[String: Any]],
            "tool_choice": "auto",
            "parallel_tool_calls": false,
            "store": false,
            "stream": true,
            "include": [] as [String]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // SSE 스트리밍 파싱
        return try await parseSSEStream(request: request, originalText: text)
    }

    /// SSE 스트리밍 응답 파싱
    private func parseSSEStream(request: URLRequest, originalText: String) async throws -> String {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return originalText
        }

        // 401 = 토큰 만료
        if httpResponse.statusCode == 401 {
            // 리프레시 시도
            if let tokens = authService.loadTokens() {
                let _ = try await authService.refreshToken(refreshToken: tokens.refresh_token)
                // 재시도는 호출자가 처리
            }
            throw AuthError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            return originalText
        }

        var result = ""

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            // delta 텍스트 축적
            if let delta = json["delta"] as? String {
                result += delta
            }
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // 마크다운 코드 펜스 제거
        let cleaned = Self.removeCodeFences(trimmed)

        return cleaned.isEmpty ? originalText : cleaned
    }

    /// 마크다운 코드 펜스 (```json ... ```) 제거
    private static func removeCodeFences(_ text: String) -> String {
        var result = text
        // ```로 시작하고 끝나는 경우 제거
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

    /// User-Agent 빌드 (Codex CLI 형식)
    private static func buildUserAgent() -> String {
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        return "codex_cli_rs/0.1.2025062 (Darwin \(osVer); arm64)"
    }

    /// 모델 변경
    func updateModel(_ newModel: OpenAIModel) {
        model = newModel
    }
}
