import Foundation

final class LightningWhisperProvider: STTProvider, @unchecked Sendable {
    let name = "Lightning-SimulWhisper"

    private var process: Process?
    private var port: Int = 0
    private var _isReady = false
    private let enginePath: String

    var isReady: Bool { _isReady }
    var isAvailable: Bool {
        // uv가 설치되어 있는지 확인
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/uv")
            || FileManager.default.fileExists(atPath: "/usr/local/bin/uv")
    }

    init(enginePath: String? = nil) {
        self.enginePath = enginePath ?? {
            // stt-engine/ 경로 탐색
            let bundlePath = Bundle.main.resourcePath.map { $0 + "/stt-engine" }
            let projectPath = FileManager.default.currentDirectoryPath + "/stt-engine"
            if let bp = bundlePath, FileManager.default.fileExists(atPath: bp) {
                return bp
            }
            return projectPath
        }()
    }

    func setup() async throws {
        guard isAvailable else {
            throw STTError.transcriptionFailed("uv is not installed. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh")
        }

        let uvPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/uv")
            ? "/opt/homebrew/bin/uv" : "/usr/local/bin/uv"

        // uv sync (첫 실행 시 의존성 설치)
        let venvPath = enginePath + "/.venv"
        if !FileManager.default.fileExists(atPath: venvPath) {
            let syncProcess = Process()
            syncProcess.executableURL = URL(fileURLWithPath: uvPath)
            syncProcess.arguments = ["sync"]
            syncProcess.currentDirectoryURL = URL(fileURLWithPath: enginePath)
            try syncProcess.run()
            syncProcess.waitUntilExit()
            guard syncProcess.terminationStatus == 0 else {
                throw STTError.transcriptionFailed("uv sync failed")
            }
        }

        // 사용 가능한 포트 찾기
        port = Self.findAvailablePort()

        // 서버 프로세스 시작
        process = Process()
        process?.executableURL = URL(fileURLWithPath: uvPath)
        process?.arguments = ["run", "python", "server.py", "--port", "\(port)"]
        process?.currentDirectoryURL = URL(fileURLWithPath: enginePath)

        // 크래시 시 재시작 (최대 3회)
        var restartCount = 0
        process?.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self, restartCount < 3, proc.terminationStatus != 0 else { return }
                restartCount += 1
                self._isReady = false
                try? await self.setup()
            }
        }

        try process?.run()

        // 서버 준비 대기 (/health 폴링, 최대 30초)
        try await waitForHealth(timeout: 30)
        _isReady = true
    }

    func teardown() async {
        _isReady = false
        // POST /shutdown
        if port > 0 {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/shutdown")!)
            request.httpMethod = "POST"
            _ = try? await URLSession.shared.data(for: request)
        }
        process?.terminate()
        process = nil
    }

    func transcribe(audioBuffer: [Float], language: SupportedLanguage?,
                    promptTokens: [Int]?) async throws -> TranscriptionResult {
        guard _isReady else { throw STTError.modelNotLoaded }

        // float32 배열을 base64로 인코딩
        let audioData = audioBuffer.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
        let base64 = audioData.base64EncodedString()

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/transcribe")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct RequestBody: Encodable {
            let audio_base64: String
            let language: String?
            let prompt: String?
        }

        request.httpBody = try JSONEncoder().encode(RequestBody(
            audio_base64: base64,
            language: language?.rawValue,
            prompt: nil
        ))

        let (data, _) = try await URLSession.shared.data(for: request)

        struct ResponseBody: Decodable {
            let text: String
            let segments: [SegmentBody]?
            let language: String?

            struct SegmentBody: Decodable {
                let text: String?
                let language: String?
            }
        }

        let response = try JSONDecoder().decode(ResponseBody.self, from: data)

        return TranscriptionResult(
            text: response.text,
            segments: response.segments?.map {
                TranscriptionSegment(text: $0.text ?? "", language: $0.language, words: nil)
            } ?? [],
            language: response.language
        )
    }

    func transcribeStream(audioBuffer: [Float], language: SupportedLanguage?,
                          promptTokens: [Int]?) -> AsyncStream<PartialTranscription> {
        AsyncStream { continuation in
            Task {
                do {
                    let result = try await self.transcribe(
                        audioBuffer: audioBuffer, language: language, promptTokens: promptTokens
                    )
                    continuation.yield(PartialTranscription(text: result.text, isFinal: true))
                } catch { }
                continuation.finish()
            }
        }
    }

    // MARK: - Helpers

    private func waitForHealth(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            do {
                let url = URL(string: "http://127.0.0.1:\(port)/health")!
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   json["status"] as? String == "ready" {
                    return
                }
            } catch { }
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5초
        }
        throw STTError.transcriptionFailed("STT engine failed to start within \(Int(timeout))s")
    }

    private static func findAvailablePort() -> Int {
        // 랜덤 포트 범위에서 사용 가능한 포트 찾기
        for _ in 0..<10 {
            let port = Int.random(in: 49152...65535)
            let sock = socket(AF_INET, SOCK_STREAM, 0)
            guard sock >= 0 else { continue }
            defer { close(sock) }

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(port).bigEndian
            addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

            let bindResult = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    bind(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if bindResult == 0 { return port }
        }
        return 49152 // fallback
    }
}
