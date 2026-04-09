import SwiftUI

/// MainDashboardView 스타일과 일치하는 카드 컨테이너
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
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(DesignTokens.textSecondary)

                    if let description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textTertiary)
                    }
                }
            }

            content
        }
        .padding(DesignTokens.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cardRadius)
                .fill(DesignTokens.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.cardRadius)
                        .fill(DesignTokens.Surface.cardTint)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.cardRadius)
                        .stroke(DesignTokens.Border.subtle, lineWidth: 1)
                }
        )
    }
}
