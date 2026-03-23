import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case general = "일반"
    case stt = "STT"
    case llm = "LLM"
    case wordSets = "단어 사전"
    case history = "기록"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .general: return "gearshape"
        case .stt: return "mic.fill"
        case .llm: return "brain"
        case .wordSets: return "text.book.closed.fill"
        case .history: return "clock.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .home: return .orange
        case .general: return .gray
        case .stt: return .blue
        case .llm: return .purple
        case .wordSets: return .teal
        case .history: return .indigo
        }
    }
}

struct UnifiedView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSection: SidebarSection = .home
    @State private var isSidebarExpanded: Bool = true

    private var sidebarWidth: CGFloat {
        isSidebarExpanded ? 220 : 80
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Sidebar
                sidebarContent
                    .frame(width: sidebarWidth)
                    .background(Color.primary.opacity(0.06))

                // Divider starting below traffic lights
                VStack(spacing: 0) {
                    Color.clear.frame(height: 52)
                    Divider()
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 1)

                // Detail — scrollContentBackground hidden so Form backgrounds are transparent
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 52)
                    .scrollContentBackground(.hidden)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        VStack(alignment: isSidebarExpanded ? .leading : .center, spacing: 0) {
            // Toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSidebarExpanded.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .frame(maxWidth: .infinity, alignment: isSidebarExpanded ? .leading : .center)
            .padding(.leading, isSidebarExpanded ? 10 : 0)
            .padding(.bottom, 16)

            // Navigation items
            ForEach(SidebarSection.allCases) { section in
                SidebarRow(
                    section: section,
                    isSelected: selectedSection == section,
                    isExpanded: isSidebarExpanded
                ) {
                    selectedSection = section
                }
            }
            Spacer()
        }
        .padding(.top, 60)
        .padding(.horizontal, isSidebarExpanded ? 14 : 8)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .home:
            MainDashboardView()
        case .general:
            GeneralSettingsView()
        case .stt:
            STTSettingsView()
        case .llm:
            LLMSettingsView()
        case .wordSets:
            DomainWordSetsView()
        case .history:
            TranscriptionHistoryView()
        }
    }
}

// MARK: - Sidebar Row

private struct SidebarRow: View {
    let section: SidebarSection
    let isSelected: Bool
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isExpanded {
                    HStack(spacing: 12) {
                        iconBadge
                        Text(section.rawValue)
                            .font(.system(size: 15))
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                } else {
                    HStack {
                        Spacer()
                        iconBadge
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .padding(.vertical, 2)
        .help(isExpanded ? "" : section.rawValue)
    }

    private var iconBadge: some View {
        Image(systemName: section.icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(section.iconColor)
            )
    }
}

// MARK: - NSVisualEffectView wrapper

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
