import AVFoundation
import Combine

@MainActor
final class AudioService: ObservableObject {
    @Published var isRecording = false
    @Published var currentLevel: Float = 0.0

    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let targetSampleRate: Double = 16000

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func checkPermission() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func startRecording() throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        bufferLock.lock()
        audioBuffer = []
        bufferLock.unlock()

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Calculate audio level (RMS)
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            if let channelData, frameLength > 0 {
                var rms: Float = 0
                for i in 0..<frameLength {
                    rms += channelData[i] * channelData[i]
                }
                rms = sqrtf(rms / Float(frameLength))
                // dB normalization with gentle curve (no over-boost)
                let db = 20 * log10f(max(rms, 1e-6))
                let normalized = max(0.0, (db + 50) / 45) // -50dB to -5dB → 0 to 1
                let level = min(1.0, normalized)

                Task { @MainActor in
                    self.currentLevel = level
                }
            }

            // Convert to target format and accumulate
            if let converter {
                let ratio = targetSampleRate / inputFormat.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                guard let convertedBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: outputFrameCapacity
                ) else { return }

                var error: NSError?
                var inputBufferConsumed = false
                converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    if inputBufferConsumed {
                        outStatus.pointee = .noDataNow
                        return nil
                    }
                    inputBufferConsumed = true
                    outStatus.pointee = .haveData
                    return buffer
                }

                if error == nil, let data = convertedBuffer.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(start: data, count: Int(convertedBuffer.frameLength)))
                    self.bufferLock.lock()
                    self.audioBuffer.append(contentsOf: samples)
                    self.bufferLock.unlock()
                }
            }
        }

        engine.prepare()
        try engine.start()
        audioEngine = engine
        isRecording = true
    }

    func stopRecording() -> [Float] {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        currentLevel = 0.0

        bufferLock.lock()
        let buffer = audioBuffer
        audioBuffer = []
        bufferLock.unlock()

        return buffer
    }
}
