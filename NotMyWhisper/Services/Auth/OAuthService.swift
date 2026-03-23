import Foundation
import Network
import CryptoKit
import AppKit

/// OpenAI OAuth PKCE 인증 서비스.
/// Codex CLI가 없는 유저를 위한 fallback 인증.
/// 브라우저에서 로그인 → localhost:1455 콜백 → 토큰 교환.
@MainActor
final class OAuthService: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var isLoggingIn: Bool = false
    @Published var loginError: String?

    private let clientId = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let authURL = "https://auth.openai.com/oauth/authorize"
    private let tokenURL = "https://auth.openai.com/oauth/token"
    private let callbackPort: UInt16 = 1455
    private let callbackRedirectURI = "http://localhost:1455/auth/callback"
    private let scope = "openid profile email offline_access"

    private let tokenPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".notmywhisper/oauth.json")

    private var codeVerifier: String?
    private var expectedState: String?

    struct OAuthTokens: Codable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int?
        let expires_at: Int?
        let token_type: String?
        let scope: String?
    }

    // MARK: - Token Management

    func loadTokens() -> OAuthTokens? {
        guard FileManager.default.fileExists(atPath: tokenPath.path),
              let data = try? Data(contentsOf: tokenPath),
              let tokens = try? JSONDecoder().decode(OAuthTokens.self, from: data) else {
            isLoggedIn = false
            return nil
        }
        isLoggedIn = true
        return tokens
    }

    func checkAuth() {
        _ = loadTokens()
    }

    /// JWT에서 chatgpt_account_id 추출
    func extractAccountId(from accessToken: String) -> String? {
        let parts = accessToken.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1])
        while base64.count % 4 != 0 {
            base64 += "="
        }

        guard let payloadData = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let authClaim = payload["https://api.openai.com/auth"] as? [String: Any],
              let accountId = authClaim["chatgpt_account_id"] as? String else {
            return nil
        }

        return accountId
    }

    // MARK: - OAuth PKCE Login Flow

    func startLogin() async {
        isLoggingIn = true
        loginError = nil

        do {
            // PKCE 생성
            let verifier = Self.generateCodeVerifier()
            let challenge = Self.generateCodeChallenge(verifier: verifier)
            let stateParam = UUID().uuidString

            codeVerifier = verifier
            expectedState = stateParam

            // Auth URL 빌드
            var components = URLComponents(string: authURL)!
            components.queryItems = [
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "redirect_uri", value: callbackRedirectURI),
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "code_challenge", value: challenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "state", value: stateParam),
                URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
                URLQueryItem(name: "originator", value: "codex_cli_rs"),
            ]

            // 브라우저 열기
            NSWorkspace.shared.open(components.url!)

            // 콜백 대기 (120초 타임아웃)
            let result = try await OAuthCallbackServer.waitForCallback(port: callbackPort, timeoutSeconds: 120)

            // State 검증 (CSRF 방지)
            guard result.state == stateParam else {
                throw OAuthError.stateMismatch
            }

            // 토큰 교환
            try await exchangeCode(result.code, verifier: verifier)

        } catch {
            loginError = error.localizedDescription
        }

        isLoggingIn = false
    }

    // MARK: - Token Exchange

    private func exchangeCode(_ code: String, verifier: String) async throws {
        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParts = [
            "grant_type=authorization_code",
            "client_id=\(clientId)",
            "code=\(code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code)",
            "redirect_uri=\(callbackRedirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? callbackRedirectURI)",
            "code_verifier=\(verifier)"
        ]
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw OAuthError.tokenExchangeFailed
        }

        var tokenData = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // 만료 시간 계산
        if let expiresIn = tokenData["expires_in"] as? Int {
            tokenData["expires_at"] = Int(Date().timeIntervalSince1970) + expiresIn
        }

        try saveTokenData(tokenData)
        isLoggedIn = true
        codeVerifier = nil
        expectedState = nil
    }

    // MARK: - Token Refresh

    func refreshAccessToken() async throws -> OAuthTokens {
        guard let tokens = loadTokens(), let refreshToken = tokens.refresh_token else {
            throw OAuthError.noRefreshToken
        }

        var request = URLRequest(url: URL(string: tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParts = [
            "grant_type=refresh_token",
            "client_id=\(clientId)",
            "refresh_token=\(refreshToken)"
        ]
        request.httpBody = bodyParts.joined(separator: "&").data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            logout()
            throw OAuthError.refreshFailed
        }

        var tokenData = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let expiresIn = tokenData["expires_in"] as? Int {
            tokenData["expires_at"] = Int(Date().timeIntervalSince1970) + expiresIn
        }

        // refresh_token이 응답에 없으면 기존 것 유지
        if tokenData["refresh_token"] == nil {
            tokenData["refresh_token"] = refreshToken
        }

        try saveTokenData(tokenData)
        return loadTokens()!
    }

    // MARK: - Logout

    func logout() {
        try? FileManager.default.removeItem(at: tokenPath)
        isLoggedIn = false
    }

    // MARK: - PKCE Helpers

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func generateCodeChallenge(verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Storage

    private func saveTokenData(_ data: [String: Any]) throws {
        let dir = tokenPath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        try jsonData.write(to: tokenPath)
    }
}

// MARK: - OAuth Callback Server

/// localhost:1455에서 OAuth 콜백을 수신하는 임시 TCP 서버.
/// 브라우저가 리다이렉트하면 code와 state를 파싱하여 반환.
enum OAuthCallbackServer {
    static func waitForCallback(port: UInt16, timeoutSeconds: Int = 120) async throws -> (code: String, state: String) {
        try await withCheckedThrowingContinuation { continuation in
            let listener: NWListener
            do {
                listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            } catch {
                continuation.resume(throwing: OAuthError.serverStartFailed)
                return
            }

            // 한 번만 resume하도록 보호
            let resumed = NSLock()
            var didResume = false

            func safeResume(with result: Result<(code: String, state: String), Error>) {
                resumed.lock()
                defer { resumed.unlock() }
                guard !didResume else { return }
                didResume = true
                listener.cancel()
                continuation.resume(with: result)
            }

            // 타임아웃
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeoutSeconds)) {
                safeResume(with: .failure(OAuthError.timeout))
            }

            listener.newConnectionHandler = { connection in
                connection.start(queue: .global())
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                    guard let data, let request = String(data: data, encoding: .utf8) else {
                        safeResume(with: .failure(OAuthError.invalidCallback))
                        return
                    }

                    // HTTP 요청에서 code, state 파싱
                    // GET /auth/callback?code=xxx&state=yyy HTTP/1.1
                    guard let firstLine = request.components(separatedBy: "\r\n").first,
                          let urlPart = firstLine.split(separator: " ").dropFirst().first,
                          let components = URLComponents(string: String(urlPart)),
                          let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
                          let state = components.queryItems?.first(where: { $0.name == "state" })?.value else {
                        let errorResp = "HTTP/1.1 400 Bad Request\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n<h1>Error</h1>"
                        connection.send(content: errorResp.data(using: .utf8), completion: .contentProcessed({ _ in
                            connection.cancel()
                        }))
                        safeResume(with: .failure(OAuthError.invalidCallback))
                        return
                    }

                    // 성공 응답
                    let html = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\n\r\n<!DOCTYPE html><html><body style=\"font-family:system-ui;text-align:center;padding:60px\"><h1>로그인 성공</h1><p>NotMyWhisper 앱으로 돌아가세요.</p><script>setTimeout(()=>window.close(),2000)</script></body></html>"
                    connection.send(content: html.data(using: .utf8), completion: .contentProcessed({ _ in
                        connection.cancel()
                    }))

                    safeResume(with: .success((code, state)))
                }
            }

            listener.stateUpdateHandler = { state in
                if case .failed = state {
                    safeResume(with: .failure(OAuthError.serverStartFailed))
                }
            }

            listener.start(queue: .global())
        }
    }
}

// MARK: - Errors

enum OAuthError: LocalizedError {
    case stateMismatch
    case serverStartFailed
    case invalidCallback
    case tokenExchangeFailed
    case noRefreshToken
    case refreshFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .stateMismatch: return "OAuth state 불일치 (CSRF 방지)"
        case .serverStartFailed: return "콜백 서버 시작 실패 (포트 1455)"
        case .invalidCallback: return "잘못된 OAuth 콜백"
        case .tokenExchangeFailed: return "토큰 교환 실패"
        case .noRefreshToken: return "리프레시 토큰 없음"
        case .refreshFailed: return "토큰 리프레시 실패"
        case .timeout: return "로그인 시간 초과 (120초)"
        }
    }
}
