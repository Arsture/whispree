import SwiftUI

/// MainDashboardView 스타일을 기반으로 한 디자인 토큰
enum DesignTokens {
    // Layout (MainDashboardView 기준)
    static let outerPadding: CGFloat = 24      // ScrollView 외부 패딩
    static let sectionSpacing: CGFloat = 20    // 섹션 간 간격
    static let cardPadding: CGFloat = 12       // 카드 내부 패딩
    static let cardRadius: CGFloat = 8         // 카드 코너 반경

    // Component Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // Border Radius
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    // Status Colors
    static let statusSuccess = Color.green
    static let statusWarning = Color.yellow
    static let statusError = Color.red
    static let statusInfo = Color.blue

    // Text Hierarchy
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // Accent
    static let accentPrimary = Color.accentColor

    // Backgrounds
    static let surfaceBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
}
