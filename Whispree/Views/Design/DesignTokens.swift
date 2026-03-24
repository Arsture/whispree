import SwiftUI

enum DesignTokens {
    // Semantic Colors
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBackgroundHover = Color(nsColor: .controlBackgroundColor).opacity(0.8)
    static let surfaceBackground = Color(nsColor: .windowBackgroundColor)

    // Accent States
    static let accentPrimary = Color.accentColor
    static let accentSubdued = Color.accentColor.opacity(0.1)

    // Status Colors
    static let statusSuccess = Color.green
    static let statusWarning = Color.orange
    static let statusError = Color.red
    static let statusInfo = Color.blue

    // Text Hierarchy
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // Spacing Scale (4px base)
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // Corner Radius
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }
}
