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

// MARK: - Waveform (slim rounded bars, real FFT data)

struct NeonWaveformView: View {
    @EnvironmentObject var appState: AppState
    private let bandCount = 48
    @State private var smoothed: [Float] = Array(repeating: 0, count: 48)

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            let totalWidth = size.width * 0.88
            let offsetX = (size.width - totalWidth) / 2
            let barSpacing = totalWidth / CGFloat(bandCount)
            let barWidth: CGFloat = max(2, barSpacing * 0.55)

            for i in 0..<bandCount {
                let level = CGFloat(smoothed[i])
                let minH: CGFloat = 1.5
                let h = max(minH, level * size.height * 0.42)
                let x = offsetX + CGFloat(i) * barSpacing + (barSpacing - barWidth) / 2
                let cornerR = barWidth / 2

                let topRect = CGRect(x: x, y: midY - h, width: barWidth, height: h)
                let botRect = CGRect(x: x, y: midY + 0.5, width: barWidth, height: h)

                // Color: subtle white-blue gradient based on position
                let t = CGFloat(i) / CGFloat(bandCount - 1)
                let color = barColor(t: t, intensity: Float(level))

                context.fill(Path(roundedRect: topRect, cornerRadius: cornerR), with: .color(color))
                context.fill(Path(roundedRect: botRect, cornerRadius: cornerR), with: .color(color))
            }

            // Subtle center line
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
            let count = min(bandCount, bands.count)

            // Resample 64 FFT bands → 48 display bars
            for i in 0..<bandCount {
                let srcIdx = Int(Float(i) / Float(bandCount) * Float(bands.count))
                let target = srcIdx < bands.count ? bands[srcIdx] : 0
                let current = smoothed[i]

                if target > current {
                    smoothed[i] = current * 0.25 + target * 0.75  // Fast attack
                } else {
                    smoothed[i] = current * 0.88 + target * 0.12  // Slow decay
                }
            }
        }
    }

    private func barColor(t: CGFloat, intensity: Float) -> Color {
        let alpha = 0.5 + Double(min(intensity, 1.0)) * 0.5
        // Clean white → light blue gradient
        let blue = 0.7 + t * 0.3
        let green = 0.8 + t * 0.15
        return Color(red: 0.75 - t * 0.2, green: green, blue: blue).opacity(alpha)
    }
}

// Alias for dashboard usage
typealias ScrollingWaveformView = NeonWaveformView
