import Foundation

final class GroqSTTProvider: STTProvider, @unchecked Sendable {
    let name = "Groq Cloud"
    var isAvailable: Bool { true }
    private let apiKey: String
    private let model = "whisper-large-v3-turbo"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func validate() -> ProviderValidation {
        apiKey.isEmpty ? .invalid("Groq API Key를 설정해주세요. Settings에서 입력할 수 있습니다.") : .valid
    }

    func setup() async throws {
        // API-based: no model download needed
        // API key is validated at transcription time
    }

    func teardown() async {}

    func transcribe(audioBuffer: [Float], language: SupportedLanguage?,
                    promptTokens: [Int]?) async throws -> TranscriptionResult {
        guard !apiKey.isEmpty else { throw STTError.modelNotLoaded }

        let wavData = Self.createWAVData(from: audioBuffer)
        let langCode = (language == nil || language == .auto) ? "ko" : language!.rawValue

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body = Data()

        // file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(wavData)
        body.append("\r\n")

        // model
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("\(model)\r\n")

        // language
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        body.append("\(langCode)\r\n")

        // response_format
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        body.append("json\r\n")

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.transcriptionFailed("Groq API: 응답 없음")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw STTError.transcriptionFailed("Groq API error (\(httpResponse.statusCode)): \(errorBody)")
        }

        struct GroqResponse: Decodable {
            let text: String
        }

        let result = try JSONDecoder().decode(GroqResponse.self, from: data)

        return TranscriptionResult(
            text: result.text,
            segments: [],
            language: langCode
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

    // MARK: - WAV Encoding

    static func createWAVData(from samples: [Float], sampleRate: Int = 16000) -> Data {
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = Int32(sampleRate) * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = Int32(samples.count) * Int32(bitsPerSample / 8)
        let fileSize = 36 + dataSize

        var data = Data(capacity: Int(fileSize) + 8)

        // RIFF header
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        data.appendLittleEndian(fileSize)
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        data.appendLittleEndian(Int32(16))
        data.appendLittleEndian(Int16(1)) // PCM
        data.appendLittleEndian(numChannels)
        data.appendLittleEndian(Int32(sampleRate))
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)

        // data chunk
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        data.appendLittleEndian(dataSize)

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let int16 = Int16(clamped * Float(Int16.max))
            data.appendLittleEndian(int16)
        }

        return data
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func append(_ string: String) {
        if let d = string.data(using: .utf8) { append(d) }
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: MemoryLayout<T>.size))
    }
}
