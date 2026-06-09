import Foundation

/// Claude Code CLI(`claude -p`)를 서브프로세스로 호출하는 LLM Provider.
///
/// 사용자가 설치/로그인한 Claude Code의 **구독 인증을 그대로 재사용**한다.
/// 이는 *genuine Claude Code binary*가 인증하는 경로로, Anthropic ToS상 구독으로 허용되는
/// 유일한 third-party 사용 방식이다 (Keychain 토큰을 빼내 raw HTTP로 직접 호출하는 방식은
/// "client identity / keychain 추출" 탐지 대상이라 **밴 위험** — 사용하지 않는다).
///
/// - **인증**: Keychain의 Claude Code OAuth를 `claude` 바이너리가 직접 사용. 별도 로그인 불필요.
/// - **과금**: `claude -p` 사용량은 Agent SDK 크레딧 풀($20/$100/$200·월)에서 차감 (대화형 한도와 별개).
/// - **속도**: subprocess라 콜드스타트(node ~3s) + 추론 → ~5-20초. 빠른 대안은 ToS상 불가.
/// - **경량화**: `--setting-sources ""`(CLAUDE.md/settings 미로드) + `--allowedTools "Read"`(빌트인 툴
///   정의 컨텍스트 제거)로 토큰·지연을 대폭 축소. OAuth 구독 인증은 그대로 유지된다.
/// - **비전**: 스크린샷을 임시파일로 쓰고 프롬프트에 `@<절대경로>`로 첨부.
///
/// GUI 앱은 로그인 셸 PATH를 상속하지 않으므로 바이너리 경로를 직접 탐색하고,
/// Keychain 조회에 필요한 `HOME`/`USER`/`LOGNAME`/`PATH`를 명시적으로 환경에 넣는다.
@MainActor
final class ClaudeCodeProvider: LLMProvider {
    let name = "Claude (구독)"
    let requiresNetwork = true
    var supportsVision: Bool { model.supportsVision }

    private var model: ClaudeCodeModel
    private let correctionTimeout: TimeInterval = 45.0

    init(model: ClaudeCodeModel) {
        self.model = model
    }

    func updateModel(_ newModel: ClaudeCodeModel) {
        model = newModel
    }

    /// 탐색된 `claude` 바이너리 경로 (없으면 nil). 최초 1회 해석 후 캐시.
    static let binaryPath: String? = resolveBinary()
    static var isAvailable: Bool { binaryPath != nil }

    func validate() -> ProviderValidation {
        Self.binaryPath == nil
            ? .invalid("Claude Code CLI를 찾을 수 없습니다. 터미널에서 설치 후 `claude` 명령으로 로그인하세요.")
            : .valid
    }

    func setup() async throws {}
    func teardown() async {}

    func correct(
        text: String,
        systemPrompt: String,
        glossary: [String]?,
        screenshots: [Data] = []
    ) async throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }
        guard let claudePath = Self.binaryPath else {
            throw LLMError.correctionFailed("Claude Code CLI 미설치")
        }

        var fullSystemPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullSystemPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        // 스크린샷 → 임시파일 → 프롬프트에 `@경로` 첨부 (최대 3장)
        var tempPaths: [String] = []
        defer { for p in tempPaths { try? FileManager.default.removeItem(atPath: p) } }

        var userPrompt = text
        if supportsVision, !screenshots.isEmpty {
            let dir = NSTemporaryDirectory()
            for shot in screenshots.suffix(3) {
                let path = dir + "whispree_claude_\(UUID().uuidString).jpg"
                if (try? shot.write(to: URL(fileURLWithPath: path))) != nil {
                    tempPaths.append(path)
                    userPrompt += " @\(path)"
                }
            }
        }

        // 컨텍스트 경량화 (속도·비용 직결):
        // - `--setting-sources ""` : CLAUDE.md/settings 미로드 (글로벌 메모리 제거, OAuth 구독은 유지)
        // - `--allowedTools "Read"`: 빌트인 툴 정의를 컨텍스트에서 제거 (이미지 `@경로`만 호환 유지)
        // variadic(`--allowedTools <tools...>`)은 바로 뒤 `--output-format`(--flag)에서 소비가 멈추므로
        // 프롬프트를 positional 마지막에 둬도 안전하다.
        let args: [String] = [
            "-p",
            "--setting-sources", "",
            "--allowedTools", "Read",
            "--output-format", "json",
            "--model", model.rawValue,
            "--system-prompt", fullSystemPrompt,
            userPrompt,
        ]

        let output = try await Self.runClaude(
            path: claudePath,
            args: args,
            timeout: correctionTimeout
        )

        let result = try Self.parseResult(output)
        let cleaned = Self.removeCodeFences(result.trimmingCharacters(in: .whitespacesAndNewlines))
        if cleaned.isEmpty { return text }

        // word-edit-distance 안전장치 — LLM 환각/잡담 시 원문 반환 (다른 provider와 동일 정책)
        let changeRatio = LocalTextProvider.wordEditDistance(text, cleaned)
        if changeRatio > 0.5 { return text }

        return cleaned
    }

    // MARK: - Process Execution

    /// `claude` 프로세스를 비차단으로 실행하고 stdout 전체를 반환. timeout 시 프로세스 종료 후 `.timeout`.
    /// 프롬프트는 args의 마지막 positional로 전달된다 (stdin 미사용 — 파이프 EOF 누락 hang 회피).
    private static func runClaude(
        path: String,
        args: [String],
        timeout: TimeInterval
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.environment = cleanEnvironment(forBinary: path)
        // 프로젝트 CLAUDE.md 자동 탐색 방지 — 중립 디렉토리에서 실행
        process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())

        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                let watchdog = DispatchWorkItem {
                    if process.isRunning { process.terminate() }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)

                process.terminationHandler = { proc in
                    watchdog.cancel()
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    if proc.terminationReason == .uncaughtSignal {
                        cont.resume(throwing: LLMError.timeout)
                    } else if output.isEmpty {
                        cont.resume(throwing: LLMError.correctionFailed("claude 응답 없음 (exit \(proc.terminationStatus))"))
                    } else {
                        cont.resume(returning: output)
                    }
                }

                do {
                    try process.run()
                } catch {
                    watchdog.cancel()
                    cont.resume(throwing: LLMError.correctionFailed("claude 실행 실패: \(error.localizedDescription)"))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }

    /// Keychain 조회 + 바이너리 탐색에 필요한 최소 환경 구성.
    /// GUI 앱은 PATH가 빈약하므로 claude 디렉토리 + 표준 bin을 보강한다.
    private static func cleanEnvironment(forBinary path: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let claudeDir = (path as NSString).deletingLastPathComponent
        let base = "\(claudeDir):/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = env["PATH"].map { "\(base):\($0)" } ?? base
        // Keychain account명으로 USER가 필요 — 누락 시 보강
        if env["USER"]?.isEmpty ?? true { env["USER"] = NSUserName() }
        if env["LOGNAME"]?.isEmpty ?? true { env["LOGNAME"] = NSUserName() }
        if env["HOME"]?.isEmpty ?? true { env["HOME"] = NSHomeDirectory() }
        return env
    }

    // MARK: - Output Parsing

    /// `--output-format json` 출력에서 `type == "result"` 객체의 `result` 필드를 추출.
    /// 경고/부가 라인이 섞일 수 있어 라인 단위로 역순 탐색한다.
    private static func parseResult(_ output: String) throws -> String {
        for line in output.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  obj["type"] as? String == "result"
            else { continue }

            if (obj["is_error"] as? Bool) == true {
                let msg = (obj["result"] as? String) ?? "알 수 없는 오류"
                throw LLMError.correctionFailed("claude: \(msg)")
            }
            return (obj["result"] as? String) ?? ""
        }
        if let data = output.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let r = obj["result"] as? String
        {
            return r
        }
        throw LLMError.correctionFailed("claude 출력 파싱 실패")
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

    // MARK: - Binary Resolution

    /// `claude` 실행 바이너리 탐색. 우선 알려진 설치 경로를 확인하고,
    /// 실패 시 로그인 셸의 `whence -p`로 (함수/alias를 건너뛴) 실제 경로를 해석.
    private static func resolveBinary() -> String? {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude",
        ]
        for c in candidates where fm.isExecutableFile(atPath: c) { return c }

        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shell.arguments = ["-lic", "whence -p claude || command -v claude"]
        let pipe = Pipe()
        shell.standardOutput = pipe
        shell.standardError = Pipe()
        do {
            try shell.run()
            shell.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let resolved = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !resolved.isEmpty, !resolved.contains("\n"), fm.isExecutableFile(atPath: resolved) {
                return resolved
            }
        } catch {}
        return nil
    }
}
