import SwiftUI

/// 모델 메트릭 표시 — STT/LLM/Downloads 탭 공통
struct ModelMetricsView: View {
    let sizeText: String            // "2.5 GB" or "☁️"
    let ramPercent: Int?            // nil for cloud
    let tokPerSec: Int?             // nil for cloud
    let latencyMs: Int?             // nil for local
    let qualityScore: Int
    let grade: CompatibilityGrade

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            CompatibilityBadge(grade: grade)

            HStack(spacing: 8) {
                // 크기
                MetricLabel(icon: "internaldrive", text: sizeText)

                // RAM (로컬만)
                if let ram = ramPercent {
                    MetricLabel(
                        icon: "memorychip",
                        text: "RAM \(ram)%",
                        color: ramColor(ram)
                    )
                }

                // 속도 (로컬 = tok/s, 클라우드 = latency)
                if let tps = tokPerSec, tps > 0 {
                    MetricLabel(icon: "bolt", text: "\(tps) tok/s")
                } else if let ms = latencyMs {
                    MetricLabel(icon: "network", text: "\(ms)ms")
                }

                // 품질
                MetricLabel(
                    icon: "chart.bar",
                    text: "Quality \(qualityScore)",
                    color: qualityColor(qualityScore)
                )
            }
        }
    }

    private func ramColor(_ percent: Int) -> Color {
        if percent >= 90 { return DesignTokens.textColor(for: .danger) }
        if percent >= 75 { return DesignTokens.textColor(for: .warning) }
        return DesignTokens.textColor(for: .tertiary)
    }

    private func qualityColor(_ score: Int) -> Color {
        if score <= 15 { return DesignTokens.textColor(for: .danger) }
        if score <= 35 { return DesignTokens.textColor(for: .warning) }
        return DesignTokens.textColor(for: .tertiary)
    }
}

/// 아이콘 + 텍스트 라벨
private struct MetricLabel: View {
    let icon: String
    let text: String
    var color: Color = DesignTokens.textSecondary

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(color)
    }
}
