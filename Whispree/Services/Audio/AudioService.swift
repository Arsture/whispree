import AVFoundation
import Combine
import Accelerate

@MainActor
final class AudioService: ObservableObject {
    @Published var isRecording = false
    @Published var currentLevel: Float = 0.0
    @Published var frequencyBands: [Float] = Array(repeating: 0, count: 64)

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

                let bands = AudioService.computeFrequencyBands(from: channelData, frameLength: frameLength)
                Task { @MainActor in
                    self.currentLevel = level
                    self.frequencyBands = bands
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

    // MARK: - FFT Frequency Analysis

    nonisolated private static func computeFrequencyBands(from data: UnsafePointer<Float>, frameLength: Int) -> [Float] {
        let bandCount = 64
        let fftSize = 1024
        guard frameLength >= fftSize else { return Array(repeating: 0, count: bandCount) }

        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return Array(repeating: 0, count: bandCount)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Hann window
        var windowed = [Float](repeating: 0, count: fftSize)
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(data, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        let halfSize = fftSize / 2
        var realp = [Float](repeating: 0, count: halfSize)
        var imagp = [Float](repeating: 0, count: halfSize)
        var magnitudes = [Float](repeating: 0, count: halfSize)

        realp.withUnsafeMutableBufferPointer { realBuf in
            imagp.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(realp: realBuf.baseAddress!, imagp: imagBuf.baseAddress!)
                windowed.withUnsafeBufferPointer { wBuf in
                    wBuf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { ptr in
                        vDSP_ctoz(ptr, 2, &split, 1, vDSP_Length(halfSize))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        // Voice-focused mapping: 80Hz~3500Hz 범위를 64밴드에 균등 분배
        // (목소리 주파수를 전체 너비에 걸쳐 센터링)
        let sampleRate: Float = 48000 // 입력 오디오 기본 샘플레이트
        let minFreq: Float = 80
        let maxFreq: Float = 3500
        let minBin = max(1, Int(minFreq / (sampleRate / Float(fftSize))))
        let maxBin = min(halfSize - 1, Int(maxFreq / (sampleRate / Float(fftSize))))
        let voiceBinRange = maxBin - minBin

        var bands = [Float](repeating: 0, count: bandCount)
        for i in 0..<bandCount {
            let t0 = Float(i) / Float(bandCount)
            let t1 = Float(i + 1) / Float(bandCount)
            // Mel-like scale within voice range
            let startBin = minBin + Int(pow(t0, 1.5) * Float(voiceBinRange))
            let endBin = min(maxBin, max(startBin, minBin + Int(pow(t1, 1.5) * Float(voiceBinRange))))

            var sum: Float = 0
            for bin in startBin...endBin {
                sum += sqrtf(magnitudes[bin])
            }
            let avg = sum / Float(max(1, endBin - startBin + 1))
            bands[i] = min(1.0, avg / 15.0)
        }
        return bands
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
