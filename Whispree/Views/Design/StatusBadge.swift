import SwiftUI

enum StatusBadgeStyle {
    case success, warning, error, info, neutral

    var colors: DesignTokens.SemanticColors {
        switch self {
            case .success: DesignTokens.semanticColors(for: .success)
            case .warning: DesignTokens.semanticColors(for: .warning)
            case .error: DesignTokens.semanticColors(for: .danger)
            case .info: DesignTokens.semanticColors(for: .accent)
            case .neutral: DesignTokens.semanticColors(for: .neutral)
        }
    }
}

struct StatusBadge: View {
    let text: String
    let icon: String?
    let style: StatusBadgeStyle

    init(_ text: String, icon: String? = nil, style: StatusBadgeStyle = .neutral) {
        self.text = text
        self.icon = icon
        self.style = style
    }

    var body: some View {
        let colors = style.colors

        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(.caption, design: .default, weight: .medium))
        }
        .foregroundStyle(colors.foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
