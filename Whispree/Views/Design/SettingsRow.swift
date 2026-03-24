import SwiftUI

struct SettingsRow<Trailing: View>: View {
    let label: String
    let description: String?
    let icon: String?
    let trailing: Trailing

    init(
        label: String,
        description: String? = nil,
        icon: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.label = label
        self.description = description
        self.icon = icon
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(DesignTokens.textPrimary)

                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.textTertiary)
                }
            }

            Spacer()

            trailing
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}
