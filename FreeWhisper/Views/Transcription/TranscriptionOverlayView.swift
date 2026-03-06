import SwiftUI

struct TranscriptionOverlayView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                statusIcon
                Text(appState.transcriptionState.displayText)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if appState.transcriptionState == .transcribing || appState.transcriptionState == .correcting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                }
            }
            NeonWaveformView()
                .frame(height: 40)
                .opacity(appState.isRecording ? 1 : 0.3)
        }
        .frame(width: 280)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    private var statusIcon: some View {
        Group {
            switch appState.transcriptionState {
            case .recording:
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse)
            case .transcribing:
                Image(systemName: "text.bubble")
                    .foregroundStyle(.orange)
            case .correcting:
                Image(systemName: "text.badge.checkmark")
                    .foregroundStyle(.blue)
            case .inserting:
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            case .idle:
                Image(systemName: "mic")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }
}

// MARK: - Neon Waveform (reference image style)

struct NeonWaveformView: View {
    @EnvironmentObject var appState: AppState
    private let barCount = 64
    @State private var levels: [Float] = Array(repeating: 0, count: 64)
    @State private var phase: Double = 0

    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let totalWidth = size.width * 0.9
            let offsetX = (size.width - totalWidth) / 2
            let barWidth = totalWidth / CGFloat(barCount)
            let gap: CGFloat = 1.5
            let w = max(1, barWidth - gap)

            for i in 0..<barCount {
                let level = CGFloat(levels[i])
                let h = max(2, level * size.height * 0.48)
                let x = offsetX + CGFloat(i) * barWidth + gap / 2

                let topRect = CGRect(x: x, y: midY - h, width: w, height: h)
                let botRect = CGRect(x: x, y: midY, width: w, height: h)

                // Color: pink → purple → cyan
                let t = CGFloat(i) / CGFloat(barCount - 1)
                let color = neonColor(t: t, intensity: Float(level))

                // Glow
                if level > 0.05 {
                    let glowH = h + 3
                    let glowTop = CGRect(x: x - 1, y: midY - glowH, width: w + 2, height: glowH)
                    let glowBot = CGRect(x: x - 1, y: midY, width: w + 2, height: glowH)
                    context.fill(Path(roundedRect: glowTop, cornerRadius: 1), with: .color(color.opacity(0.2)))
                    context.fill(Path(roundedRect: glowBot, cornerRadius: 1), with: .color(color.opacity(0.2)))
                }

                // Bars
                context.fill(Path(roundedRect: topRect, cornerRadius: 1), with: .color(color))
                context.fill(Path(roundedRect: botRect, cornerRadius: 1), with: .color(color))
            }

            // Center line
            var line = Path()
            line.move(to: CGPoint(x: offsetX, y: midY))
            line.addLine(to: CGPoint(x: offsetX + totalWidth, y: midY))
            context.stroke(line, with: .color(.white.opacity(0.15)), lineWidth: 0.5)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.9))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onReceive(timer) { _ in
            phase += 0.15
            let current = appState.currentAudioLevel

            for i in 0..<barCount {
                let center = Float(barCount) / 2
                let dist = abs(Float(i) - center) / center // 0 at center, 1 at edges

                // Gaussian-like falloff: center peaks hard, edges stay tiny
                let spatial = powf(1.0 - dist, 2.5)

                // Per-bar organic variation (each bar has its own rhythm)
                let wave1 = sin(Float(i) * 0.9 + Float(phase) * 1.3) * 0.3
                let wave2 = sin(Float(i) * 0.3 + Float(phase) * 0.7) * 0.2
                let noise = max(0.1, 0.5 + wave1 + wave2)

                let target = current * spatial * noise
                // Smooth transition
                levels[i] = levels[i] * 0.65 + target * 0.35
            }
        }
    }

    private func neonColor(t: CGFloat, intensity: Float) -> Color {
        let alpha = 0.6 + Double(min(intensity, 1.0)) * 0.4
        // Pink (0.0) → Purple (0.5) → Cyan (1.0)
        if t < 0.5 {
            let s = t / 0.5
            return Color(
                red: 0.95 - s * 0.4,
                green: 0.2 + s * 0.15,
                blue: 0.75 + s * 0.15
            ).opacity(alpha)
        } else {
            let s = (t - 0.5) / 0.5
            return Color(
                red: 0.55 - s * 0.45,
                green: 0.35 + s * 0.55,
                blue: 0.9 + s * 0.1
            ).opacity(alpha)
        }
    }
}

// Alias for dashboard usage
typealias ScrollingWaveformView = NeonWaveformView
