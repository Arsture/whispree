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
                        .foregroundStyle(DesignTokens.textColor(for: .secondary))

                    if let description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textColor(for: .tertiary))
                    }
                }
            }

            content
        }
        .padding(DesignTokens.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.surfaceBackgroundView())
    }
}
