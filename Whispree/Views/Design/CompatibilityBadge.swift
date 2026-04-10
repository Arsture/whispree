import SwiftUI

/// 호환성 등급 배지 (RUNS GREAT ~ TOO HEAVY)
struct CompatibilityBadge: View {
    let grade: CompatibilityGrade

    var body: some View {
        let colors = DesignTokens.semanticColors(for: grade.semanticTone)

        Text(grade.rawValue)
            .font(.system(.caption2, weight: .bold))
            .foregroundStyle(colors.foreground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(colors.background)
                    .overlay {
                        Capsule()
                            .stroke(colors.border, lineWidth: 1)
                    }
            )
    }
}

private extension CompatibilityGrade {
    var semanticTone: DesignTokens.SemanticTone {
        switch self {
        case .runsGreat, .runsWell, .decent:
            .neutral
        case .tightFit:
            .warning
        case .barelyRuns, .tooHeavy:
            .danger
        }
    }
}
