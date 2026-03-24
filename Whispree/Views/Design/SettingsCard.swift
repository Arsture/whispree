import SwiftUI

struct SettingsCard<Content: View>: View {
    let title: String?
    let description: String?
    let content: Content

    init(
        title: String? = nil,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if let title = title {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(title)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(DesignTokens.textPrimary)

                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
            }

            content
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                .fill(DesignTokens.cardBackground)
                .shadow(color: .black.opacity(0.03), radius: 1, x: 0, y: 1)
        )
    }
}
