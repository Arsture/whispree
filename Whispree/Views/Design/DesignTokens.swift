import SwiftUI

/// MainDashboardView 스타일을 기반으로 한 디자인 토큰
enum DesignTokens {
    // Layout (MainDashboardView 기준)
    static let outerPadding: CGFloat = 24 // ScrollView 외부 패딩
    static let sectionSpacing: CGFloat = 20 // 섹션 간 간격
    static let cardPadding: CGFloat = 12 // 카드 내부 패딩
    static let cardRadius: CGFloat = 12 // 카드 코너 반경

    /// Component Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// Border Radius
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
    }

    enum Palette {
        /// Keep system accent for primary highlights so the sidebar accent language remains aligned.
        static let accent = Color(nsColor: .controlAccentColor)
        static let success = Color(red: 0.20, green: 0.67, blue: 0.49)
        static let warning = Color(red: 0.84, green: 0.60, blue: 0.22)
        static let danger = Color(red: 0.83, green: 0.39, blue: 0.46)
        static let neutral = Color(nsColor: .secondaryLabelColor)
    }

    // Text Hierarchy
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    enum TextRole {
        case primary
        case secondary
        case tertiary
        case accent
        case success
        case warning
        case danger
    }

    /// Accent
    static let accentPrimary = Palette.accent

    enum Surface {
        static let background = Color(nsColor: .windowBackgroundColor)
        static let card = Color(nsColor: .controlBackgroundColor)
        static let cardTint = Color.primary.opacity(0.03)
        static let subdued = Color.primary.opacity(0.05)
        static let overlay = Color(nsColor: .underPageBackgroundColor)
    }

    enum Border {
        static let subtle = Color.primary.opacity(0.08)
        static let emphasized = Color.primary.opacity(0.14)
    }

    struct SemanticColors {
        let foreground: Color
        let background: Color
        let border: Color
    }

    struct SurfaceStyle {
        let material: Material
        let tint: Color
        let border: Color
        let highlight: Color
        let shadow: Color
    }

    enum SemanticTone {
        case accent
        case success
        case warning
        case danger
        case neutral
    }

    enum SurfaceRole {
        /// Main content cards / settings groups. Neutral and quiet.
        case card
        /// Inset wells / shortcuts / small grouped controls.
        case inset
        /// Floating shells / selection surfaces that need slightly stronger separation.
        case overlay
    }

    enum InteractionRole {
        /// Current selection/focus/active row. Uses accent, never semantic colors.
        case selection
    }

    static func semanticColors(for tone: SemanticTone) -> SemanticColors {
        switch tone {
        case .accent:
            semanticColors(base: Palette.accent)
        case .success:
            semanticColors(base: Palette.success)
        case .warning:
            semanticColors(base: Palette.warning)
        case .danger:
            semanticColors(base: Palette.danger)
        case .neutral:
            SemanticColors(
                foreground: textSecondary,
                background: Surface.subdued,
                border: Border.subtle
            )
        }
    }

    static func textColor(for role: TextRole) -> Color {
        switch role {
        case .primary:
            textPrimary
        case .secondary:
            textSecondary
        case .tertiary:
            textTertiary
        case .accent:
            accentPrimary
        case .success:
            semanticColors(for: .success).foreground
        case .warning:
            semanticColors(for: .warning).foreground
        case .danger:
            semanticColors(for: .danger).foreground
        }
    }

    static func surfaceStyle(for role: SurfaceRole) -> SurfaceStyle {
        switch role {
        case .card:
            SurfaceStyle(
                material: .regularMaterial,
                tint: Color.white.opacity(0.05),
                border: Color.white.opacity(0.22),
                highlight: Color.white.opacity(0.24),
                shadow: Color.black.opacity(0.12)
            )
        case .inset:
            SurfaceStyle(
                material: .ultraThinMaterial,
                tint: Color.white.opacity(0.03),
                border: Color.white.opacity(0.14),
                highlight: Color.white.opacity(0.16),
                shadow: Color.black.opacity(0.04)
            )
        case .overlay:
            SurfaceStyle(
                material: .regularMaterial,
                tint: Color.white.opacity(0.07),
                border: Color.white.opacity(0.26),
                highlight: Color.white.opacity(0.30),
                shadow: Color.black.opacity(0.18)
            )
        }
    }

    static func interactionColors(for role: InteractionRole) -> SemanticColors {
        switch role {
        case .selection:
            semanticColors(base: Palette.accent, backgroundOpacity: 0.11, borderOpacity: 0.3)
        }
    }

    @ViewBuilder
    static func surfaceBackgroundView(
        role: SurfaceRole = .card,
        cornerRadius: CGFloat = cardRadius
    ) -> some View {
        let surface = surfaceStyle(for: role)
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(surface.material)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(surface.tint)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [surface.highlight, .clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(surface.border, lineWidth: 1)
            }
            .shadow(color: surface.shadow, radius: role == .overlay ? 14 : 8, y: role == .overlay ? 6 : 3)
    }

    // Backwards-compatible aliases for shared components that still consume the simple tokens.
    static let statusSuccess = Palette.success
    static let statusWarning = Palette.warning
    static let statusError = Palette.danger
    static let statusInfo = Palette.accent
    static let surfaceBackground = Surface.background
    static let cardBackground = Surface.card

    private static func semanticColors(
        base: Color,
        backgroundOpacity: Double = 0.14,
        borderOpacity: Double = 0.22
    ) -> SemanticColors {
        SemanticColors(
            foreground: base,
            background: base.opacity(backgroundOpacity),
            border: base.opacity(borderOpacity)
        )
    }
}
