import Foundation
import OSLog

@MainActor
final class OpenAIProvider: LLMProvider {
    let name = "OpenAI (GPT)"
    let requiresNetwork = true

    private let authService: CodexAuthService
    private let oauthService: OAuthService
    private(set) var model: String
    /// 카탈로그에 있는 모델이면 vision/effort 정보를 쓴다. 없으면 nil.
    private var catalogEntry: CodexModel?
    /// 사용자가 고른 reasoning effort. 빈 문자열이면 자동(가장 낮은 값). 요청마다 읽으므로 재시작 없이 반영된다.
    var reasoningEffortPreference: String

    nonisolated static let logger = Logger(subsystem: "com.whispree.app", category: "LLM")
    private static let requestTimeout: TimeInterval = 30
    private static let errorBodyLimit = 2048

    /// 카탈로그에 없으면 vision 지원으로 간주 (기존 동작 유지).
    var supportsVision: Bool { catalogEntry?.supportsVision ?? true }

    func validate() -> ProviderValidation {
        if authService.isLoggedIn || oauthService.isLoggedIn {
            return .valid
        }
        return .invalid("OpenAI 인증이 필요합니다. Codex CLI 로그인 또는 OAuth 인증을 해주세요.")
    }

    init(
        model: String = CodexModelCatalog.defaultModelSlug,
        catalog: [CodexModel] = CodexModelCatalog.load(),
        reasoningEffortPreference: String = "",
        authService: CodexAuthService,
        oauthService: OAuthService
    ) {
        self.model = model
        catalogEntry = catalog.first { $0.slug == model }
        self.reasoningEffortPreference = reasoningEffortPreference
        self.authService = authService
        self.oauthService = oauthService
    }

    func setup() async throws {
        // Auth is checked at correction time, not during setup
        authService.checkAuth()
        oauthService.checkAuth()
    }

    func teardown() async {
        // 네트워크 Provider는 특별한 해제 불필요
    }

    func correct(text: String, systemPrompt: String, glossary: [String]?, screenshots: [Data] = []) async throws -> String {
        // glossary를 시스템 프롬프트에 동적 주입
        var fullPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        let (accessToken, accountId) = try getAuth()

        // ChatGPT Responses API 요청 구성
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/codex/responses")!)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(Self.buildUserAgent(), forHTTPHeaderField: "User-Agent")
        request.setValue("codex_cli_rs", forHTTPHeaderField: "originator")

        // 스크린샷이 있으면 Vision 멀티모달 content, 없으면 텍스트 전용
        var userContent: [[String: Any]] = []
        // 최근 5장까지만 전송 (토큰 절약)
        let recentScreenshots = screenshots.suffix(5)
        for screenshotData in recentScreenshots {
            let base64Image = screenshotData.base64EncodedString()
            userContent.append(["type": "input_image", "image_url": "data:image/jpeg;base64,\(base64Image)"])
        }
        userContent.append(["type": "input_text", "text": text])

        let body = Self.makeRequestBody(
            model: model,
            reasoningEffort: CodexModelCatalog.resolveEffort(entry: catalogEntry, preference: reasoningEffortPreference),
            instructions: fullPrompt,
            userContent: userContent
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // SSE 스트리밍 파싱
        let result = try await parseSSEStream(request: request)

        // 안전장치: 출력이 입력보다 2.5배 이상 길면 답변 생성으로 판단
        if result == text { return result }
        let inputWords = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        let outputWords = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        if inputWords > 0, Double(outputWords) / Double(inputWords) > 2.5 {
            Self.logger.notice(
                "OpenAI: output too long (\(outputWords, privacy: .public)/\(inputWords, privacy: .public) words) — keeping original model=\(self.model, privacy: .public)"
            )
            return text
        }

        return result
    }

    static func makeRequestBody(
        model: String,
        reasoningEffort: String?,
        instructions: String,
        userContent: [[String: Any]]
    ) -> [String: Any] {
        var body: [String: Any] = [
            "model": model,
            "instructions": instructions,
            "input": [
                ["type": "message", "role": "user", "content": userContent]
            ],
            "tools": [] as [[String: Any]],
            "tool_choice": "auto",
            "parallel_tool_calls": false,
            "store": false,
            "stream": true,
            "include": [] as [String]
        ]
        // 서버가 허용하지 않는 effort는 403이므로, 모를 때는 필드 자체를 생략한다.
        if let reasoningEffort {
            body["reasoning"] = ["effort": reasoningEffort]
        }
        return body
    }

    // MARK: - Auth Resolution

    /// Codex 토큰 우선, 없으면 OAuth 토큰 사용
    private func getAuth() throws -> (accessToken: String, accountId: String) {
        // 1. Codex CLI 토큰
        if let codexTokens = authService.loadTokens() {
            return (codexTokens.access_token, codexTokens.account_id)
        }

        // 2. OAuth 토큰 (JWT에서 account_id 추출)
        if let oauthTokens = oauthService.loadTokens() {
            guard let accountId = oauthService.extractAccountId(from: oauthTokens.access_token) else {
                throw AuthError.notAuthenticated
            }
            return (oauthTokens.access_token, accountId)
        }

        throw AuthError.notAuthenticated
    }

    // MARK: - SSE Streaming

    private func parseSSEStream(request: URLRequest) async throws -> String {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("OpenAI: non-HTTP response model=\(self.model, privacy: .public)")
            throw LLMError.correctionFailed("HTTP 응답 아님")
        }

        // 401 = 토큰 만료 → 리프레시 시도
        if httpResponse.statusCode == 401 {
            Self.logger.error("OpenAI: HTTP 401 — refreshing token model=\(self.model, privacy: .public)")
            try await refreshCurrentAuth()
            throw AuthError.tokenExpired
        }

        guard httpResponse.statusCode == 200 else {
            let body = await Self.readErrorBody(bytes)
            Self.logger.error(
                "OpenAI: HTTP \(httpResponse.statusCode, privacy: .public) model=\(self.model, privacy: .public) body=\(body, privacy: .public)"
            )
            throw LLMError.correctionFailed("HTTP \(httpResponse.statusCode): \(Self.serverMessage(from: body))")
        }

        var result = ""

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }

            if let failure = Self.streamFailureMessage(from: json) {
                Self.logger.error(
                    "OpenAI: stream failure model=\(self.model, privacy: .public) message=\(failure, privacy: .public)"
                )
                throw LLMError.correctionFailed(failure)
            }

            // delta 텍스트 축적
            if let delta = json["delta"] as? String {
                result += delta
            }
        }

        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = Self.removeCodeFences(trimmed)
        guard !cleaned.isEmpty else {
            Self.logger.error("OpenAI: empty streamed result model=\(self.model, privacy: .public)")
            throw LLMError.correctionFailed("빈 응답")
        }
        return cleaned
    }

    /// SSE 이벤트가 실패(`response.failed` / `error`)이면 서버 메시지를 반환.
    static func streamFailureMessage(from json: [String: Any]) -> String? {
        let type = json["type"] as? String
        guard type == "response.failed" || type == "error" else { return nil }
        let label = type ?? "error"
        let response = json["response"] as? [String: Any]
        let error = (response?["error"] as? [String: Any]) ?? (json["error"] as? [String: Any]) ?? json
        guard let summary = codeAndMessage(error) else { return label }
        return "\(label) \(summary)"
    }

    /// 에러 응답 body에서 사람이 읽을 메시지를 추출. JSON이 아니면 body 그대로.
    static func serverMessage(from body: String) -> String {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return body
        }
        for key in ["error", "detail"] {
            if let dict = json[key] as? [String: Any], let summary = codeAndMessage(dict) { return summary }
        }
        if let detail = json["detail"] as? String { return detail }
        return body
    }

    private static func codeAndMessage(_ dict: [String: Any]) -> String? {
        let message = dict["message"] as? String
        let code = dict["code"] as? String
        switch (code, message) {
        case let (code?, message?): return "\(code): \(message)"
        case let (nil, message?): return message
        case let (code?, nil): return code
        default: return nil
        }
    }

    private static func readErrorBody(_ bytes: URLSession.AsyncBytes) async -> String {
        var data = Data()
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count >= errorBodyLimit { break }
            }
        } catch {
            // body 일부만 읽혀도 로그용으로 충분
        }
        return String(decoding: data, as: UTF8.self)
    }

    /// 현재 활성 인증 방식의 토큰을 리프레시
    private func refreshCurrentAuth() async throws {
        // Codex 토큰이 있으면 Codex 리프레시
        if let codexTokens = authService.loadTokens() {
            _ = try await authService.refreshToken(refreshToken: codexTokens.refresh_token)
            return
        }

        // OAuth 토큰이 있으면 OAuth 리프레시
        if oauthService.isLoggedIn {
            _ = try await oauthService.refreshAccessToken()
        }
    }

    // MARK: - Utilities

    /// 마크다운 코드 펜스 (```json ... ```) 제거
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

    /// User-Agent 빌드 (Codex CLI 형식)
    private static func buildUserAgent() -> String {
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        return "codex_cli_rs/0.1.2025062 (Darwin \(osVer); arm64)"
    }

    /// 모델 변경
    func updateModel(_ newModel: String, catalog: [CodexModel] = CodexModelCatalog.load()) {
        model = newModel
        catalogEntry = catalog.first { $0.slug == newModel }
    }
}
