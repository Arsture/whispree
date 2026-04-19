import SwiftUI

/// Onboarding + GeneralSettings에서 재사용하는 권한 행 컴포넌트.
struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: PermissionManager.Status
    /// nil이면 status 기반 자동 결정: notDetermined→"허용하기", denied→"설정 열기"
    var actionLabel: String? = nil
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DesignTokens.accentPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailing
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(DesignTokens.semanticColors(for: .success).foreground)
        case .unavailable:
            Text("미설치")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .denied, .notDetermined:
            Button(action: onAction) {
                Text(computedActionLabel)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(DesignTokens.accentPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var computedActionLabel: String {
        actionLabel ?? (status == .denied ? "설정 열기" : "허용하기")
    }
}

/// Automation 섹션에 표시할 대상 앱 목록 (SystemEvents 등 내부용 제외).
struct AutomationTarget {
    let bundleID: String
    let icon: String
    let name: String
    let description: String

    static let all: [AutomationTarget] = [
        AutomationTarget(bundleID: "com.apple.Music",       icon: "music.note",          name: "Apple Music",   description: "녹음 중 음악 자동 일시정지"),
        AutomationTarget(bundleID: "com.spotify.client",    icon: "music.quarternote.3", name: "Spotify",       description: "녹음 중 음악 자동 일시정지"),
        AutomationTarget(bundleID: "com.google.Chrome",     icon: "globe",               name: "Google Chrome", description: "탭 복원 및 입력 필드 포커스"),
        AutomationTarget(bundleID: "com.googlecode.iterm2", icon: "terminal.fill",       name: "iTerm2",        description: "터미널 pane 위치 복원"),
    ]
}
