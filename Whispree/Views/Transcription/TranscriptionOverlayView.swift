import KeyboardShortcuts
import SwiftUI

struct TranscriptionOverlayView: View {
    @EnvironmentObject var appState: AppState

    /// 녹음 중 thinking pause 상태인가? (UI 전환 기준)
    private var isThinkingPauseActive: Bool {
        appState.settings.vadEnabled &&
            appState.transcriptionState == .recording &&
            appState.isThinkingPause
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                statusIcon
                Text(statusText)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.35), value: isThinkingPauseActive)
                Spacer(minLength: 0)
                if appState.transcriptionState == .transcribing || appState.transcriptionState == .correcting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            NeonWaveformView()
                .frame(height: 40)
                .opacity(waveformOpacity)
                .animation(.easeInOut(duration: 0.4), value: isThinkingPauseActive)
                .animation(.easeInOut(duration: 0.2), value: appState.isRecording)

            if appState.isRecording {
                HStack(spacing: 12) {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Stop")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(shortcutLabel)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DesignTokens.Surface.subdued)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    HStack(spacing: 4) {
                        Text("Cancel")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("esc")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(DesignTokens.Surface.subdued)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    Spacer()
                }
            }
        }
        .frame(width: 280)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private var shortcutLabel: String {
        if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) {
            return shortcut.description
        }
        return "⌃⇧R"
    }

    private var statusText: String {
        if isThinkingPauseActive {
            return String(localized: "무음 스킵 중")
        }
        return appState.transcriptionState.displayText
    }

    private var waveformOpacity: Double {
        if !appState.isRecording { return 0.3 }
        return isThinkingPauseActive ? 0.35 : 1.0
    }

    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if isThinkingPauseActive {
                // Thinking pause: "무음 스킵 중" — waveform.slash (secondary), gentle pulse
                Image(systemName: "waveform.slash")
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse, options: .repeating.speed(0.6))
            } else {
                switch appState.transcriptionState {
                    case .recording:
                        Image(systemName: "mic.fill")
                            .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground)
                            .symbolEffect(.pulse)
                    case .transcribing:
                        Image(systemName: "text.bubble")
                            .foregroundStyle(DesignTokens.semanticColors(for: .warning).foreground)
                    case .correcting:
                        Image(systemName: "text.badge.checkmark")
                            .foregroundStyle(DesignTokens.accentPrimary)
                    case .inserting:
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
                    case .selectingScreenshots:
                        Image(systemName: "photo.on.rectangle.angled")
                            .foregroundStyle(DesignTokens.accentPrimary)
                    case .idle:
                        Image(systemName: "mic")
                            .foregroundStyle(.secondary)
                }
            }
        }
        .font(.caption)
        .contentTransition(.symbolEffect(.replace))
        .animation(.easeInOut(duration: 0.3), value: isThinkingPauseActive)
    }
}

// MARK: - Waveform (스펙트럼 중앙 접기 — 저주파→중앙, 고주파→가장자리)

struct NeonWaveformView: View {
    @EnvironmentObject var appState: AppState
    private let bandCount = 48
    private let halfCount = 24
    @State private var smoothed: [Float] = Array(repeating: 0, count: 48)

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    // 바 인덱스 → FFT 밴드 인덱스 매핑 (중앙 접기)
    // 중앙(23,24) → fft[0,1], 가장자리(0,47) → fft[46,47]
    private let barToFFT: [Int] = {
        var map = [Int](repeating: 0, count: 48)
        for i in 0 ..< 24 {
            let fftIdx = (23 - i) * 2      // 왼쪽: 짝수 밴드
            let fftIdx2 = (23 - i) * 2 + 1 // 오른쪽: 홀수 밴드
            map[i] = fftIdx
            map[47 - i] = fftIdx2
        }
        return map
    }()

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let totalWidth = size.width * 0.88
            let offsetX = (size.width - totalWidth) / 2
            let barSpacing = totalWidth / CGFloat(bandCount)
            let barWidth: CGFloat = max(2, barSpacing * 0.55)

            for i in 0 ..< bandCount {
                let level = CGFloat(smoothed[i])
                let minH: CGFloat = 1.5
                let h = max(minH, level * size.height * 0.42)
                let x = offsetX + CGFloat(i) * barSpacing + (barSpacing - barWidth) / 2
                let cornerR = barWidth / 2

                let topRect = CGRect(x: x, y: midY - h, width: barWidth, height: h)
                let botRect = CGRect(x: x, y: midY + 0.5, width: barWidth, height: h)

                let center = Float(bandCount - 1) / 2.0
                let distFromCenter = CGFloat(abs(Float(i) - center) / center)
                let color = barColor(dist: distFromCenter, intensity: Float(level))

                context.fill(Path(roundedRect: topRect, cornerRadius: cornerR), with: .color(color))
                context.fill(Path(roundedRect: botRect, cornerRadius: cornerR), with: .color(color))
            }

            var centerLine = Path()
            centerLine.move(to: CGPoint(x: offsetX, y: midY))
            centerLine.addLine(to: CGPoint(x: offsetX + totalWidth, y: midY))
            context.stroke(centerLine, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.08))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onReceive(timer) { _ in
            let bands = appState.frequencyBands
            let rms = appState.currentAudioLevel

            for i in 0 ..< bandCount {
                // 중앙 접기: 저주파→중앙, 고주파→가장자리 (좌우 다른 밴드)
                let fftIdx = min(barToFFT[i], max(bands.count - 1, 0))
                let fftVal: Float = bands.isEmpty ? 0 : bands[fftIdx]

                // FFT가 형태를 결정, RMS가 전체 에너지 스케일링
                let target = fftVal * (0.6 + rms * 1.4)

                let current = smoothed[i]
                if target > current {
                    smoothed[i] = current * 0.2 + target * 0.8
                } else {
                    smoothed[i] = current * 0.85 + target * 0.15
                }
            }
        }
    }

    private func barColor(dist: CGFloat, intensity: Float) -> Color {
        let alpha = 0.5 + Double(min(intensity, 1.0)) * 0.5
        let r = 0.55 + dist * 0.25
        let g = 0.82 - dist * 0.15
        let b = 0.95
        return Color(red: r, green: g, blue: b).opacity(alpha)
    }
}

/// Alias for dashboard usage
typealias ScrollingWaveformView = NeonWaveformView
