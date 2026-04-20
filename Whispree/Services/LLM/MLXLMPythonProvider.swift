import Foundation

/// mlx-lm Python worker를 통한 LLM 교정 Provider.
/// mlx-swift-lm에 아직 포팅되지 않은 아키텍처(Gemma4 MoE 등) 지원용.
@MainActor
final class MLXLMPythonProvider: LLMProvider {
    /// setup 도중 진행 단계 (UI 표시용)
    enum SetupPhase: Equatable {
        case uvSync                        // uv venv 의존성 설치 중 (진행률 없음)
        case downloading(progress: Double) // 모델 다운로드 중 (0-1)
        case loading                       // 다운로드 완료, 모델을 메모리에 로드 중
    }

    typealias ProgressHandler = @MainActor @Sendable (SetupPhase) -> Void

    let name = "로컬 LLM (Python)"
    let requiresNetwork = false
    let supportsVision = false

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var readBuffer = Data()

    private var _isReady = false
    private let modelId: String
    private let workerPath: String
    private let progressHandler: ProgressHandler?
    private let correctionTimeout: TimeInterval = 60.0

    func validate() -> ProviderValidation {
        _isReady ? .valid : .invalid("Python LLM 워커가 준비되지 않았습니다.")
    }

    var isAvailable: Bool {
        Self.findUvPath() != nil
    }

    init(modelId: String, progressHandler: ProgressHandler? = nil) {
        self.modelId = modelId
        self.workerPath = Self.resolveWorkerPath()
        self.progressHandler = progressHandler
    }

    // MARK: - uv / worker path 해석 (MLXAudioProvider와 동일 패턴)

    private static func findUvPath() -> String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/uv",
            "/opt/homebrew/bin/uv",
            "/usr/local/bin/uv",
        ]
        for path in candidates where fm.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    private static func resolveWorkerPath() -> String {
        let fm = FileManager.default
        let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Whispree/mlx-worker")
        let appSupportPath = appSupportURL.path

        // 개발 모드: 프로젝트 디렉토리의 mlx_llm_worker.py가 가장 최신 (Bundle 복사 지연 대비)
        let devPath = fm.currentDirectoryPath + "/mlx-worker"
        if fm.fileExists(atPath: devPath + "/mlx_llm_worker.py") {
            return devPath
        }

        // Bundle → Application Support 복사
        if let bundlePath = Bundle.main.resourcePath.map({ $0 + "/mlx-worker" }),
           fm.fileExists(atPath: bundlePath + "/mlx_llm_worker.py")
        {
            try? fm.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            for file in ["mlx_worker.py", "mlx_llm_worker.py", "pyproject.toml"] {
                let src = bundlePath + "/" + file
                let dst = appSupportPath + "/" + file
                if fm.fileExists(atPath: src) {
                    try? fm.removeItem(atPath: dst)
                    try? fm.copyItem(atPath: src, toPath: dst)
                }
            }
            return appSupportPath
        }

        return appSupportPath
    }

    // MARK: - LLMProvider

    func setup() async throws {
        guard let uvPath = Self.findUvPath() else {
            throw LLMError.correctionFailed(
                "uv가 설치되어 있지 않습니다. `curl -LsSf https://astral.sh/uv/install.sh | sh`로 설치하세요."
            )
        }
        guard FileManager.default.fileExists(atPath: workerPath + "/mlx_llm_worker.py") else {
            throw LLMError.correctionFailed("mlx_llm_worker.py를 찾을 수 없습니다: \(workerPath)")
        }

        // uv sync — 항상 실행 (멱등). 앱 업데이트로 pyproject.toml이 바뀐 경우
        // .venv만 존재하고 lock이 stale한 상태에서 `uv run`이 재해결에 실패하는 회귀를
        // 방지. 변경 없을 땐 거의 즉시 리턴하며 네트워크도 타지 않음.
        let venvPath = workerPath + "/.venv"
        let venvExists = FileManager.default.fileExists(atPath: venvPath)
        progressHandler?(.uvSync)
        let syncProcess = Process()
        syncProcess.executableURL = URL(fileURLWithPath: uvPath)
        syncProcess.arguments = ["sync"]
        syncProcess.currentDirectoryURL = URL(fileURLWithPath: workerPath)
        let syncStderrPipe = Pipe()
        syncProcess.standardError = syncStderrPipe
        syncProcess.standardOutput = FileHandle.nullDevice
        try syncProcess.run()
        syncProcess.waitUntilExit()
        if syncProcess.terminationStatus != 0 {
            let errData = syncStderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let hint = venvExists ? " (기존 .venv를 삭제해보세요)" : ""
            throw LLMError.correctionFailed("uv sync 실패\(hint): \(errText)")
        }

        // stderr는 파일로 리디렉션 — 문제 발생 시 원인 파악 가능
        let logURL = Self.stderrLogURL()
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let stderrHandle = try FileHandle(forWritingTo: logURL)

        // 파이프 + 프로세스 기동
        let stdin = Pipe()
        let stdout = Pipe()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: uvPath)
        proc.arguments = ["run", "python", "mlx_llm_worker.py"]
        proc.currentDirectoryURL = URL(fileURLWithPath: workerPath)
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = stderrHandle
        try proc.run()

        process = proc
        stdinPipe = stdin
        stdoutPipe = stdout
        readBuffer = Data()

        // ready 대기
        let ready = try await readResponse(timeout: 10)
        guard ready["status"] as? String == "ready" else {
            throw LLMError.correctionFailed("Worker가 준비되지 않았습니다")
        }

        // 모델 로드
        // 캐시가 이미 예상 크기의 95% 이상이면 다운로드 완료로 보고 진행률 UI 스킵.
        let expectedBytes = LocalModelSpec.find(modelId)?.sizeBytes ?? 0
        let initialDisk = ModelManager.cachedBlobsSize(repoId: modelId)
        let alreadyDownloaded = expectedBytes > 0
            && Double(initialDisk) / Double(expectedBytes) >= 0.95

        let targetRepo = modelId
        let pollerHandler = progressHandler
        let pollerTask: Task<Void, Never>?
        if alreadyDownloaded {
            progressHandler?(.loading)
            pollerTask = nil
        } else {
            progressHandler?(.downloading(progress: Double(initialDisk) / Double(max(expectedBytes, 1))))
            pollerTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if Task.isCancelled { break }
                    let disk = ModelManager.cachedBlobsSize(repoId: targetRepo)
                    if expectedBytes > 0 {
                        let fraction = min(Double(disk) / Double(expectedBytes), 0.99)
                        pollerHandler?(.downloading(progress: fraction))
                    }
                }
            }
        }

        try sendCommand(["cmd": "load", "model": modelId])
        let loadResp = try await readResponse(timeout: 1800)
        pollerTask?.cancel()
        guard loadResp["ok"] as? Bool == true else {
            let err = loadResp["error"] as? String ?? Self.tailStderrLog()
            throw LLMError.correctionFailed("모델 로드 실패: \(err)")
        }

        // 워밍업 (메모리 로드 + JIT). 대형 MoE 첫 forward pass는 수 분 걸릴 수 있음.
        progressHandler?(.loading)
        try sendCommand(["cmd": "warmup"])
        _ = try await readResponse(timeout: 600)

        _isReady = true
    }

    /// `~/Library/Logs/Whispree/mlx_llm_worker.log` — 워커 stderr 리디렉션 대상.
    static func stderrLogURL() -> URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/Whispree", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mlx_llm_worker.log")
    }

    /// 로그 파일 마지막 ~8KB를 읽어 에러 메시지 맥락으로 사용.
    static func tailStderrLog() -> String {
        let url = stderrLogURL()
        guard let data = try? Data(contentsOf: url) else { return "워커가 응답하지 않음" }
        let tailBytes = 8_192
        let slice = data.suffix(tailBytes)
        let text = String(data: slice, encoding: .utf8) ?? ""
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "워커가 응답하지 않음" : trimmed
    }

    func teardown() async {
        _isReady = false
        if let proc = process, proc.isRunning {
            try? sendCommand(["cmd": "quit"])
            try? await Task.sleep(nanoseconds: 500_000_000)
            if proc.isRunning { proc.terminate() }
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        readBuffer = Data()
    }

    func correct(
        text: String,
        systemPrompt: String,
        glossary: [String]?,
        screenshots: [Data] = []
    ) async throws -> String {
        guard _isReady else { throw LLMError.modelNotLoaded }

        var fullPrompt = systemPrompt
        if let glossary, !glossary.isEmpty {
            fullPrompt += "\n\n용어 사전 (반드시 이 형태로 보존):\n" + glossary.joined(separator: ", ")
        }

        try sendCommand([
            "cmd": "correct",
            "system_prompt": fullPrompt,
            "user_text": text,
            "max_tokens": 2000,
            "temperature": 0.0,
        ])

        let response = try await readResponse(timeout: correctionTimeout)
        guard response["ok"] as? Bool == true else {
            let err = response["error"] as? String ?? "교정 실패"
            throw LLMError.correctionFailed(err)
        }

        let output = (response["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if output.isEmpty { return text }

        // word-edit-distance 안전장치 (LocalTextProvider와 동일)
        let ratio = LocalTextProvider.wordEditDistance(text, output)
        if ratio > 0.5 { return text }

        return output
    }

    // MARK: - IPC (MLXAudioProvider 동일 패턴)

    private func sendCommand(_ command: [String: Any]) throws {
        guard let stdinPipe else { throw LLMError.correctionFailed("Worker not running") }
        let data = try JSONSerialization.data(withJSONObject: command)
        var line = data
        line.append(UInt8(ascii: "\n"))
        stdinPipe.fileHandleForWriting.write(line)
    }

    private func readResponse(timeout: TimeInterval) async throws -> [String: Any] {
        guard let stdoutPipe else { throw LLMError.correctionFailed("Worker not running") }
        let deadline = Date().addingTimeInterval(timeout)
        let handle = stdoutPipe.fileHandleForReading

        while Date() < deadline {
            if let newlineIndex = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = readBuffer[readBuffer.startIndex ..< newlineIndex]
                readBuffer = Data(readBuffer[(newlineIndex + 1)...])
                if let json = try? JSONSerialization.jsonObject(with: Data(lineData)) as? [String: Any] {
                    return json
                }
            }
            let newData = await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    continuation.resume(returning: handle.availableData)
                }
            }
            if newData.isEmpty {
                throw LLMError.correctionFailed("Worker process terminated unexpectedly")
            }
            readBuffer.append(newData)
        }
        throw LLMError.timeout
    }
}
