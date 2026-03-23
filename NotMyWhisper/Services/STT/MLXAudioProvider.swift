import Foundation

final class MLXAudioProvider: STTProvider, @unchecked Sendable {
    let name = "MLX Audio"

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var readBuffer = Data()

    private var _isReady = false
    private let modelId: String
    private let workerPath: String

    func validate() -> ProviderValidation {
        _isReady ? .valid : .invalid("MLX Audio 모델이 로드되지 않았습니다.")
    }

    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/uv")
            || FileManager.default.fileExists(atPath: "/usr/local/bin/uv")
    }

    init(modelId: String = "mlx-community/Qwen3-ASR-1.7B-8bit") {
        self.modelId = modelId

        // mlx-worker/ 경로 탐색
        let bundlePath = Bundle.main.resourcePath.map { $0 + "/mlx-worker" }
        let projectPath = FileManager.default.currentDirectoryPath + "/mlx-worker"
        let appSupportPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first.map { $0.appendingPathComponent("NotMyWhisper/mlx-worker").path }

        if let bp = bundlePath, FileManager.default.fileExists(atPath: bp + "/mlx_worker.py") {
            self.workerPath = bp
        } else if FileManager.default.fileExists(atPath: projectPath + "/mlx_worker.py") {
            self.workerPath = projectPath
        } else if let asp = appSupportPath, FileManager.default.fileExists(atPath: asp + "/mlx_worker.py") {
            self.workerPath = asp
        } else {
            self.workerPath = projectPath
        }
    }

    func setup() async throws {
        guard isAvailable else {
            throw STTError.transcriptionFailed("uv가 설치되어 있지 않습니다. curl -LsSf https://astral.sh/uv/install.sh | sh 로 설치하세요.")
        }

        guard FileManager.default.fileExists(atPath: workerPath + "/mlx_worker.py") else {
            throw STTError.transcriptionFailed("mlx-worker/mlx_worker.py를 찾을 수 없습니다: \(workerPath)")
        }

        let uvPath = FileManager.default.fileExists(atPath: "/opt/homebrew/bin/uv")
            ? "/opt/homebrew/bin/uv" : "/usr/local/bin/uv"

        // uv sync (첫 실행 시 의존성 설치)
        let venvPath = workerPath + "/.venv"
        if !FileManager.default.fileExists(atPath: venvPath) {
            let syncProcess = Process()
            syncProcess.executableURL = URL(fileURLWithPath: uvPath)
            syncProcess.arguments = ["sync"]
            syncProcess.currentDirectoryURL = URL(fileURLWithPath: workerPath)
            try syncProcess.run()
            syncProcess.waitUntilExit()
            guard syncProcess.terminationStatus == 0 else {
                throw STTError.transcriptionFailed("uv sync failed")
            }
        }

        // 파이프 설정
        let stdin = Pipe()
        let stdout = Pipe()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: uvPath)
        proc.arguments = ["run", "python", "mlx_worker.py"]
        proc.currentDirectoryURL = URL(fileURLWithPath: workerPath)
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = FileHandle.nullDevice

        try proc.run()

        self.process = proc
        self.stdinPipe = stdin
        self.stdoutPipe = stdout
        self.readBuffer = Data()

        // ready 신호 대기
        let readyResponse = try await readResponse(timeout: 10)
        guard readyResponse["status"] as? String == "ready" else {
            throw STTError.transcriptionFailed("Worker가 준비되지 않았습니다.")
        }

        // 모델 로드
        try sendCommand(["cmd": "load", "model": modelId])
        let loadResponse = try await readResponse(timeout: 120) // 모델 다운로드 포함 시 오래 걸릴 수 있음
        guard loadResponse["ok"] as? Bool == true else {
            let error = loadResponse["error"] as? String ?? "Unknown error"
            throw STTError.transcriptionFailed("모델 로드 실패: \(error)")
        }

        // 워밍업
        try sendCommand(["cmd": "warmup"])
        _ = try await readResponse(timeout: 30)

        _isReady = true
    }

    func teardown() async {
        _isReady = false
        if let _ = process, process?.isRunning == true {
            try? sendCommand(["cmd": "quit"])
            // 짧은 대기 후 강제 종료
            try? await Task.sleep(nanoseconds: 500_000_000)
            if process?.isRunning == true {
                process?.terminate()
            }
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        readBuffer = Data()
    }

    func transcribe(audioBuffer: [Float], language: SupportedLanguage?,
                    promptTokens: [Int]?) async throws -> TranscriptionResult {
        guard _isReady else { throw STTError.modelNotLoaded }

        // float32 배열을 temp WAV 파일로 저장
        let tempPath = try writeTemporaryWAV(audioBuffer: audioBuffer)

        var cmd: [String: Any] = ["cmd": "transcribe", "path": tempPath]
        if let lang = language {
            cmd["language"] = lang.rawValue
        }

        try sendCommand(cmd)
        let response = try await readResponse(timeout: 60)

        guard response["ok"] as? Bool == true else {
            let error = response["error"] as? String ?? "Transcription failed"
            throw STTError.transcriptionFailed(error)
        }

        let text = response["text"] as? String ?? ""
        return TranscriptionResult(
            text: text,
            segments: [TranscriptionSegment(text: text, language: language?.rawValue, words: nil)],
            language: language?.rawValue
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

    // MARK: - IPC Helpers

    private func sendCommand(_ command: [String: Any]) throws {
        guard let stdinPipe else { throw STTError.transcriptionFailed("Worker not running") }
        let data = try JSONSerialization.data(withJSONObject: command)
        var line = data
        line.append(contentsOf: [UInt8(ascii: "\n")])
        stdinPipe.fileHandleForWriting.write(line)
    }

    private func readResponse(timeout: TimeInterval) async throws -> [String: Any] {
        guard let stdoutPipe else { throw STTError.transcriptionFailed("Worker not running") }

        let deadline = Date().addingTimeInterval(timeout)
        let handle = stdoutPipe.fileHandleForReading

        while Date() < deadline {
            // 버퍼에서 줄바꿈 찾기
            if let newlineIndex = readBuffer.firstIndex(of: UInt8(ascii: "\n")) {
                let lineData = readBuffer[readBuffer.startIndex..<newlineIndex]
                readBuffer = Data(readBuffer[(newlineIndex + 1)...])

                if let json = try? JSONSerialization.jsonObject(with: Data(lineData)) as? [String: Any] {
                    return json
                }
            }

            // 데이터 읽기 (비동기)
            let newData = await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    let data = handle.availableData
                    continuation.resume(returning: data)
                }
            }

            if newData.isEmpty {
                // EOF — 프로세스 종료됨
                throw STTError.transcriptionFailed("Worker process terminated unexpectedly")
            }
            readBuffer.append(newData)
        }

        throw STTError.transcriptionFailed("Worker response timeout (\(Int(timeout))s)")
    }

    // MARK: - Audio Helpers

    private func writeTemporaryWAV(audioBuffer: [Float]) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".wav")
        let path = tempFile.path

        // WAV 헤더 + PCM int16 데이터
        let sampleRate: UInt32 = 16000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let dataSize = UInt32(audioBuffer.count * 2)

        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        header.append(withUnsafeBytes(of: (36 + dataSize).littleEndian) { Data($0) })
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        header.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: (sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: (numChannels * bitsPerSample / 8).littleEndian) { Data($0) })
        header.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        header.append(contentsOf: "data".utf8)
        header.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        // float32 → int16 변환
        let int16Samples = audioBuffer.map { sample -> Int16 in
            let clamped = max(-1.0, min(1.0, sample))
            return Int16(clamped * 32767.0)
        }

        var pcmData = Data(capacity: int16Samples.count * 2)
        for sample in int16Samples {
            pcmData.append(withUnsafeBytes(of: sample.littleEndian) { Data($0) })
        }

        var fileData = header
        fileData.append(pcmData)
        try fileData.write(to: tempFile)

        return path
    }
}
