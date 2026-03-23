import Foundation

@MainActor
final class CodexAuthService: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentAccountId: String?

    private let codexAuthPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".codex/auth.json")

    struct CodexAuth: Codable {
        let tokens: CodexTokens?
        let last_refresh: String?
        let OPENAI_API_KEY: String?
    }

    struct CodexTokens: Codable {
        let access_token: String
        let refresh_token: String
        let account_id: String
        let id_token: String?
    }

    /// ~/.codex/auth.json에서 토큰 읽기
    func loadTokens() -> CodexTokens? {
        guard FileManager.default.fileExists(atPath: codexAuthPath.path),
              let data = try? Data(contentsOf: codexAuthPath),
              let auth = try? JSONDecoder().decode(CodexAuth.self, from: data),
              let tokens = auth.tokens else {
            isLoggedIn = false
            currentAccountId = nil
            return nil
        }
        isLoggedIn = true
        currentAccountId = tokens.account_id
        return tokens
    }

    /// 토큰 리프레시
    func refreshToken(refreshToken: String) async throws -> CodexTokens {
        var request = URLRequest(url: URL(string: "https://auth.openai.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": "app_EMoamEEZ73f0CkXaXp7hrann"
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.refreshFailed
        }

        struct RefreshResponse: Codable {
            let access_token: String
            let refresh_token: String?
            let id_token: String?
            let expires_in: Int?
        }

        let refreshResult = try JSONDecoder().decode(RefreshResponse.self, from: data)

        // 기존 auth.json 업데이트
        let existingTokens = loadTokens()
        let newTokens = CodexTokens(
            access_token: refreshResult.access_token,
            refresh_token: refreshResult.refresh_token ?? refreshToken,
            account_id: existingTokens?.account_id ?? currentAccountId ?? "",
            id_token: refreshResult.id_token ?? existingTokens?.id_token
        )

        try saveTokens(newTokens)
        isLoggedIn = true
        currentAccountId = newTokens.account_id
        return newTokens
    }

    /// 토큰 저장
    private func saveTokens(_ tokens: CodexTokens) throws {
        let auth = CodexAuth(
            tokens: tokens,
            last_refresh: ISO8601DateFormatter().string(from: Date()),
            OPENAI_API_KEY: nil
        )
        let data = try JSONEncoder().encode(auth)
        try data.write(to: codexAuthPath)
    }

    /// 인증 상태 확인
    func checkAuth() {
        _ = loadTokens()
    }
}

enum AuthError: LocalizedError {
    case refreshFailed
    case notAuthenticated
    case tokenExpired

    var errorDescription: String? {
        switch self {
        case .refreshFailed: return "Token refresh failed"
        case .notAuthenticated: return "Not authenticated with OpenAI"
        case .tokenExpired: return "Token has expired"
        }
    }
}
