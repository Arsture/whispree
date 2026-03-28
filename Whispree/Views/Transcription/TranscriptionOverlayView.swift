import KeyboardShortcuts
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
                            .background(.quaternary.opacity(0.5))
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
                            .background(.quaternary.opacity(0.5))
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
                case .selectingScreenshots:
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(.purple)
                case .idle:
                    Image(systemName: "mic")
                        .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }
}

// MARK: - Waveform (FFT 직접 매핑 — 실제 주파수 스펙트럼 반영)

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
                // FFT 64밴드 → 48바 선형 보간 매핑
                let fftPos = Float(i) / Float(bandCount - 1) * Float(max(bands.count - 1, 0))
                let lo = Int(fftPos)
                let hi = min(lo + 1, max(bands.count - 1, 0))
                let frac = fftPos - Float(lo)
                let fftVal: Float = bands.isEmpty ? 0 : bands[lo] * (1 - frac) + bands[hi] * frac

                // 약한 중앙 강조 (center=1.0, edges=0.7) — 종모양 아님
                let center = Float(bandCount - 1) / 2.0
                let dist = abs(Float(i) - center) / center
                let centerWeight: Float = 1.0 - dist * 0.3

                // FFT가 형태를 결정, RMS가 전체 에너지 스케일링
                let target = fftVal * centerWeight * (0.6 + rms * 1.4)

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
