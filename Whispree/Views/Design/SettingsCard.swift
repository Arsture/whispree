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
            if let title = title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            content
        }
        .padding(DesignTokens.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.cardRadius)
                .fill(.quaternary.opacity(0.5))  // MainDashboardView와 동일
        )
    }
}
