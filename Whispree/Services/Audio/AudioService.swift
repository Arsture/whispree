import Accelerate
import AVFoundation
import Combine

@MainActor
final class AudioService: ObservableObject {
    @Published var isRecording = false
    @Published var currentLevel: Float = 0.0
    @Published var frequencyBands: [Float] = Array(repeating: 0, count: 64)
    /// 첫 발화 이후, 일정 시간 이상 무음이 지속되면 true.
    /// UI에서 "무음 스킵 중" 인디케이터를 띄우기 위해 사용.
    @Published var isThinkingPause = false

    private var audioEngine: AVAudioEngine?
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()
    private let targetSampleRate: Double = 16_000

    // MARK: - Thinking Pause Detection

    /// raw RMS 기준 무음 판정 threshold (탭 콜백의 raw RMS와 동일 단위)
    /// 조용한 방 기준 ~0.005 이하가 일반적. 키보드/숨소리는 0.01 근처.
    /// VAD가 실제 발화까지 잘라먹지 않도록 보수적으로 낮춘 값.
    private let silenceRMSThreshold: Float = 0.004
    /// Thinking pause UX 전용 threshold.
    /// 실제 VAD trim보다 높게 잡아 아주 작은 숨소리/배경 잡음은 "계속 말하는 중"으로 보지 않음.
    private let thinkingPauseHoldRMSThreshold: Float = 0.014
    /// 이 이상 무음이 지속되면 thinking pause 상태로 전환 (초)
    private let thinkingPauseDelay: TimeInterval = 2.0
    /// 첫 발화 판정을 위한 threshold (약간 높게 — 진짜 발화만 카운트)
    private let firstSpeechRMSThreshold: Float = 0.015
    private var lastVoiceTime: Date?
    private var hasSpokenOnce = false

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

    func startRecording(channelSelection: Int = 0) throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        bufferLock.lock()
        audioBuffer = []
        bufferLock.unlock()

        // Thinking pause 상태 초기화
        lastVoiceTime = nil
        hasSpokenOnce = false
        isThinkingPause = false

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        // Build a mono input format at the native sample rate for the converter.
        // This lets us feed extracted mono samples regardless of device channel count.
        let monoInputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: inputFormat.sampleRate,
            channels: 1,
            interleaved: false
        )!

        let converter = AVAudioConverter(from: monoInputFormat, to: targetFormat)

        // Capture by value so the audio thread never crosses MainActor isolation
        let capturedChannelSelection = channelSelection

        inputNode.installTap(onBus: 0, bufferSize: 4_096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }

            // Extract mono samples (mixdown or specific channel)
            let monoSamples = AudioService.extractMonoSamples(from: buffer, channelSelection: capturedChannelSelection)

            // Calculate audio level (RMS) and FFT from mono samples
            monoSamples.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                var rms: Float = 0
                for i in 0 ..< frameLength { rms += base[i] * base[i] }
                rms = sqrtf(rms / Float(frameLength))
                let db = 20 * log10f(max(rms, 1e-6))
                let normalized = max(0.0, (db + 50) / 45) // -50dB to -5dB → 0 to 1
                let level = min(1.0, normalized)
                let bands = AudioService.computeFrequencyBands(from: base, frameLength: frameLength)
                let capturedRMS = rms
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.currentLevel = level
                    self.frequencyBands = bands
                    self.updateThinkingPause(rawRMS: capturedRMS)
                }
            }

            // Build a mono AVAudioPCMBuffer from extracted samples and convert to target format
            if let converter,
               let monoBuffer = AVAudioPCMBuffer(pcmFormat: monoInputFormat, frameCapacity: AVAudioFrameCount(frameLength)),
               let dest = monoBuffer.floatChannelData?[0]
            {
                monoBuffer.frameLength = AVAudioFrameCount(frameLength)
                monoSamples.withUnsafeBufferPointer { src in
                    if let base = src.baseAddress {
                        dest.update(from: base, count: frameLength)
                    }
                }

                let ratio = targetSampleRate / inputFormat.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(frameLength) * ratio)
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
                    return monoBuffer
                }

                if error == nil, let data = convertedBuffer.floatChannelData?[0] {
                    let samples = Array(UnsafeBufferPointer(start: data, count: Int(convertedBuffer.frameLength)))
                    bufferLock.lock()
                    audioBuffer.append(contentsOf: samples)
                    bufferLock.unlock()
                }
            }
        }

        engine.prepare()
        try engine.start()
        audioEngine = engine
        isRecording = true
    }

    // MARK: - Channel Extraction

    /// 입력 버퍼에서 모노 샘플 배열을 추출합니다. 오디오 스레드에서 호출되므로 nonisolated static.
    /// - channelSelection 0: 모든 채널 평균 다운믹스
    /// - channelSelection 1~N: 해당 채널(1-indexed) 사용. 범위 초과 시 채널 1로 폴백.
    private nonisolated static func extractMonoSamples(from buffer: AVAudioPCMBuffer, channelSelection: Int) -> [Float] {
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard let channelData = buffer.floatChannelData, frameLength > 0, channelCount > 0 else {
            return Array(repeating: 0, count: max(frameLength, 0))
        }

        if channelSelection >= 1, channelSelection <= channelCount {
            // 특정 채널 (1-indexed)
            let ch = channelData[channelSelection - 1]
            return Array(UnsafeBufferPointer(start: ch, count: frameLength))
        } else {
            // 자동 다운믹스: 모든 채널 평균 (클리핑 방지)
            var mono = [Float](repeating: 0, count: frameLength)
            for c in 0 ..< channelCount {
                let ch = channelData[c]
                for i in 0 ..< frameLength {
                    mono[i] += ch[i]
                }
            }
            if channelCount > 1 {
                let divisor = Float(channelCount)
                for i in 0 ..< frameLength {
                    mono[i] /= divisor
                }
            }
            return mono
        }
    }

    // MARK: - FFT Frequency Analysis

    private nonisolated static func computeFrequencyBands(from data: UnsafePointer<Float>, frameLength: Int) -> [Float] {
        let bandCount = 64
        let fftSize = 1_024
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
        let sampleRate: Float = 48_000 // 입력 오디오 기본 샘플레이트
        let minFreq: Float = 80
        let maxFreq: Float = 3_500
        let minBin = max(1, Int(minFreq / (sampleRate / Float(fftSize))))
        let maxBin = min(halfSize - 1, Int(maxFreq / (sampleRate / Float(fftSize))))
        let voiceBinRange = maxBin - minBin

        var bands = [Float](repeating: 0, count: bandCount)
        for i in 0 ..< bandCount {
            let t0 = Float(i) / Float(bandCount)
            let t1 = Float(i + 1) / Float(bandCount)
            // Mel-like scale within voice range
            let startBin = minBin + Int(pow(t0, 1.5) * Float(voiceBinRange))
            let endBin = min(maxBin, max(startBin, minBin + Int(pow(t1, 1.5) * Float(voiceBinRange))))

            var sum: Float = 0
            for bin in startBin ... endBin {
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
        isThinkingPause = false
        lastVoiceTime = nil
        hasSpokenOnce = false

        bufferLock.lock()
        let buffer = audioBuffer
        audioBuffer = []
        bufferLock.unlock()

        return buffer
    }

    // MARK: - Thinking Pause

    /// 매 오디오 프레임마다 호출되어 thinking pause 상태를 갱신.
    /// - 첫 발화가 확인되기 전에는 절대 true로 전환하지 않음 (녹음 직후 "무음 스킵 중"
    ///   인디케이터가 뜨는 걸 방지).
    /// - 발화가 감지되면 lastVoiceTime 갱신 + isThinkingPause = false.
    /// - 무음이 `thinkingPauseDelay` 이상 지속되면 isThinkingPause = true.
    private func updateThinkingPause(rawRMS: Float) {
        let now = Date()

        if rawRMS >= firstSpeechRMSThreshold {
            // 명확한 발화 — 첫 발화 플래그 세팅 + 타이머 리셋
            hasSpokenOnce = true
            lastVoiceTime = now
            if isThinkingPause { isThinkingPause = false }
        } else if rawRMS >= thinkingPauseHoldRMSThreshold, hasSpokenOnce {
            // 발화에 가까운 에너지 — 타이머만 연장 (첫 발화 트리거는 아님)
            // 작은 숨소리/배경 잡음은 여기서 걸러서 "무음 스킵 중" UI가 더 잘 뜨게 함.
            lastVoiceTime = now
            if isThinkingPause { isThinkingPause = false }
        } else if hasSpokenOnce, let last = lastVoiceTime {
            // 무음 — 경과 시간이 delay를 넘으면 thinking pause
            if now.timeIntervalSince(last) >= thinkingPauseDelay {
                if !isThinkingPause { isThinkingPause = true }
            }
        }
    }

    // MARK: - Voice Activity Detection (Silence Trimming)

    /// 녹음된 버퍼에서 무음 구간을 제거.
    /// - 100ms 프레임 단위로 RMS 계산 → threshold 이상 프레임만 "active"로 판정.
    /// - 연속된 active 프레임을 하나의 세그먼트로 묶고, 앞뒤 `paddingMs`만큼 패딩.
    /// - WhisperKit/Groq/MLX Audio 공통 pre-processing으로 사용.
    ///
    /// - Parameters:
    ///   - audio: 16kHz mono Float 버퍼
    ///   - sampleRate: 기본 16000
    ///   - rmsThreshold: raw RMS threshold (기본 0.004, AudioService의 silenceRMSThreshold와 동일 기준)
    ///   - frameMs: 분석 프레임 길이 (기본 100ms)
    ///   - paddingMs: 발화 세그먼트 앞뒤 패딩 (기본 350ms — 약한 어미/초성 보호)
    ///   - minSilenceMs: 이 이상 연속 무음만 컷 (기본 900ms — 생각/호흡 pause 보존 우선)
    /// - Returns: 무음이 제거된 [Float] 버퍼. 전체가 무음으로 판정되면 원본 반환.
    nonisolated static func trimSilence(
        _ audio: [Float],
        sampleRate: Int = 16_000,
        rmsThreshold: Float = 0.004,
        frameMs: Int = 100,
        paddingMs: Int = 350,
        minSilenceMs: Int = 900
    ) -> [Float] {
        let frameSize = (sampleRate * frameMs) / 1_000
        let paddingFrames = max(1, Int(ceil(Double(paddingMs) / Double(frameMs))))
        let minSilenceFrames = max(1, Int(ceil(Double(minSilenceMs) / Double(frameMs))))

        guard audio.count >= frameSize * 2 else { return audio }

        let frameCount = audio.count / frameSize
        var isActive = [Bool](repeating: false, count: frameCount)

        audio.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            for i in 0 ..< frameCount {
                var meanSq: Float = 0
                vDSP_measqv(base + (i * frameSize), 1, &meanSq, vDSP_Length(frameSize))
                let rms = sqrtf(meanSq)
                isActive[i] = rms >= rmsThreshold
            }
        }

        // 짧은 무음 구간(<minSilenceFrames)은 active로 덮어쓰기 (문장 내 짧은 숨소리 보존)
        var i = 0
        while i < frameCount {
            if !isActive[i] {
                var runEnd = i
                while runEnd < frameCount, !isActive[runEnd] { runEnd += 1 }
                let runLength = runEnd - i
                // run이 minSilenceFrames 미만이고 앞뒤로 active 프레임이 있으면 유지
                if runLength < minSilenceFrames, i > 0, runEnd < frameCount {
                    for k in i ..< runEnd { isActive[k] = true }
                }
                i = runEnd
            } else {
                i += 1
            }
        }

        // Active 세그먼트 추출 (padding 포함)
        var result: [Float] = []
        result.reserveCapacity(audio.count)
        var segStart: Int? = nil
        for idx in 0 ..< frameCount {
            if isActive[idx] {
                if segStart == nil { segStart = idx }
            } else if let start = segStart {
                let paddedStart = max(0, start - paddingFrames)
                let paddedEnd = min(frameCount, idx + paddingFrames)
                let sampleStart = paddedStart * frameSize
                let sampleEnd = min(audio.count, paddedEnd * frameSize)
                result.append(contentsOf: audio[sampleStart ..< sampleEnd])
                segStart = nil
            }
        }
        if let start = segStart {
            let paddedStart = max(0, start - paddingFrames)
            let sampleStart = paddedStart * frameSize
            result.append(contentsOf: audio[sampleStart ..< audio.count])
        }

        // 안전장치: 트림 결과가 비었거나 극단적으로 짧으면 원본 반환 (false positive 방지)
        return result.count >= frameSize ? result : audio
    }
}
