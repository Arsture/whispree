import SwiftUI

/// 호환성 등급 배지 (RUNS GREAT ~ TOO HEAVY)
struct CompatibilityBadge: View {
    let grade: CompatibilityGrade

    var body: some View {
        Text(grade.rawValue)
            .font(.system(.caption2, weight: .bold))
            .foregroundStyle(grade.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(grade.color.opacity(0.15))
            .clipShape(Capsule())
    }
}
