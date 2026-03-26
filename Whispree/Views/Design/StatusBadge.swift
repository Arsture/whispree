import SwiftUI

enum StatusBadgeStyle {
    case success, warning, error, info, neutral

    var color: Color {
        switch self {
            case .success: DesignTokens.statusSuccess
            case .warning: DesignTokens.statusWarning
            case .error: DesignTokens.statusError
            case .info: DesignTokens.statusInfo
            case .neutral: DesignTokens.textSecondary
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
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.system(.caption, design: .default, weight: .medium))
        }
        .foregroundStyle(style.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(style.color.opacity(0.12))
        )
    }
}
