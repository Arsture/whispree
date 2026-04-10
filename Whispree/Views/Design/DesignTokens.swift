import SwiftUI

/// Liquid glass design system for Whispree.
enum DesignTokens {
    // Layout
    static let outerPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let cardPadding: CGFloat = 12
    static let cardRadius: CGFloat = 18

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 16
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 30
    }

    enum Palette {
        static let accent = Color(nsColor: .controlAccentColor)
        static let success = Color(red: 0.20, green: 0.67, blue: 0.49)
        static let warning = Color(red: 0.84, green: 0.60, blue: 0.22)
        static let danger = Color(red: 0.83, green: 0.39, blue: 0.46)
        static let neutral = Color(nsColor: .secondaryLabelColor)
    }

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    enum TextRole {
        case primary, secondary, tertiary, accent, success, warning, danger
    }

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
        case accent, success, warning, danger, neutral
    }

    enum SurfaceRole {
        /// Main content cards / settings groups.
        case card
        /// Inset wells / small grouped controls. Feels recessed.
        case inset
        /// Editing shells / larger configuration surfaces.
        case editor
        /// Floating shells / selection surfaces.
        case overlay
    }

    enum InteractionRole {
        case selection
    }

    static func semanticColors(for tone: SemanticTone) -> SemanticColors {
        switch tone {
        case .accent: semanticColors(base: Palette.accent)
        case .success: semanticColors(base: Palette.success)
        case .warning: semanticColors(base: Palette.warning)
        case .danger: semanticColors(base: Palette.danger)
        case .neutral:
            SemanticColors(foreground: textSecondary, background: Surface.subdued, border: Border.subtle)
        }
    }

    static func textColor(for role: TextRole) -> Color {
        switch role {
        case .primary: textPrimary
        case .secondary: textSecondary
        case .tertiary: textTertiary
        case .accent: accentPrimary
        case .success: semanticColors(for: .success).foreground
        case .warning: semanticColors(for: .warning).foreground
        case .danger: semanticColors(for: .danger).foreground
        }
    }

    // MARK: - Surface Styles

    static func surfaceStyle(for role: SurfaceRole) -> SurfaceStyle {
        switch role {
        case .card:
            SurfaceStyle(
                material: .regularMaterial,
                tint: Color.white.opacity(0.02),
                border: Color.white.opacity(0.06),
                highlight: Color.white.opacity(0.06),
                shadow: Color.black.opacity(0.06)
            )
        case .inset:
            SurfaceStyle(
                material: .ultraThinMaterial,
                tint: Color.black.opacity(0.02),
                border: Color.white.opacity(0.04),
                highlight: Color.white.opacity(0.02),
                shadow: Color.black.opacity(0.01)
            )
        case .editor:
            SurfaceStyle(
                material: .regularMaterial,
                tint: Color.white.opacity(0.03),
                border: Color.white.opacity(0.08),
                highlight: Color.white.opacity(0.08),
                shadow: Color.black.opacity(0.08)
            )
        case .overlay:
            SurfaceStyle(
                material: .thickMaterial,
                tint: Color.white.opacity(0.04),
                border: Color.white.opacity(0.12),
                highlight: Color.white.opacity(0.10),
                shadow: Color.black.opacity(0.10)
            )
        }
    }

    static func interactionColors(for role: InteractionRole) -> SemanticColors {
        switch role {
        case .selection:
            semanticColors(base: Palette.accent, backgroundOpacity: 0.11, borderOpacity: 0.3)
        }
    }

    // MARK: - Surface Background

    @ViewBuilder
    static func surfaceBackgroundView(
        role: SurfaceRole = .card,
        cornerRadius: CGFloat = cardRadius
    ) -> some View {
        let surface = surfaceStyle(for: role)
        let isElevated = (role == .overlay || role == .editor)
        let shadowR: CGFloat = isElevated ? 12 : 8
        let shadowY: CGFloat = isElevated ? 4 : 3
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface.material)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surface.tint)
            }
            .shadow(color: surface.shadow, radius: shadowR, y: shadowY)
    }

    // MARK: - Selected Surface (neutral, no accent color)

    @ViewBuilder
    static func selectedSurfaceBackground(cornerRadius: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.05))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
    }

    // Backwards-compatible aliases
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

// MARK: - Liquid Section Container

struct LiquidSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.surfaceBackgroundView(role: .card))
        }
    }
}

// MARK: - View Extensions

extension View {
    func liquidBackground() -> some View {
        self
    }
}
