import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case general = "일반"
    case stt = "STT"
    case llm = "LLM"
    case models = "Downloads"
    case wordSets = "단어 사전"
    case history = "기록"

    var id: String {
        rawValue
    }

    var icon: String {
        switch self {
            case .home: "house.fill"
            case .general: "gearshape"
            case .stt: "mic.fill"
            case .llm: "brain"
            case .models: "arrow.down.circle.fill"
            case .wordSets: "text.book.closed.fill"
            case .history: "clock.fill"
        }
    }

    var iconColor: Color {
        switch self {
            case .home: .orange
            case .general: .gray
            case .stt: .blue
            case .llm: .purple
            case .models: .green
            case .wordSets: .teal
            case .history: .indigo
        }
    }
}

struct UnifiedView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSection: SidebarSection = .home
    @State private var isSidebarExpanded: Bool = true
    // 방문한 탭만 mount해서 launch-time cost는 피하되, 한 번 방문한 뒤에는
    // 계속 유지해 .task/body 재실행 없이 즉시 전환되도록. 스크롤 위치/입력 state도 보존됨.
    @State private var visitedSections: Set<SidebarSection> = [.home]

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
                    selectSection(section)
                }
            }
            Spacer()
        }
        .padding(.top, 60)
        .padding(.horizontal, isSidebarExpanded ? 14 : 8)
    }

    // MARK: - Section selection

    private func selectSection(_ section: SidebarSection) {
        guard selectedSection != section else { return }
        // mount은 애니메이션 밖 — 뷰가 트리에 즉시 들어가야 fade-in이 자연스러움
        visitedSections.insert(section)
        withAnimation(.easeInOut(duration: 0.18)) {
            selectedSection = section
        }
    }

    // MARK: - Detail

    /// ZStack에 방문한 탭들을 유지하고 opacity + hit-testing만 토글.
    /// switch-based destroy/recreate로 인한 body/.task 재실행 렉을 제거.
    private var detailView: some View {
        ZStack {
            if visitedSections.contains(.home) {
                MainDashboardView()
                    .opacity(selectedSection == .home ? 1 : 0)
                    .allowsHitTesting(selectedSection == .home)
            }
            if visitedSections.contains(.general) {
                GeneralSettingsView()
                    .opacity(selectedSection == .general ? 1 : 0)
                    .allowsHitTesting(selectedSection == .general)
            }
            if visitedSections.contains(.stt) {
                STTSettingsView()
                    .opacity(selectedSection == .stt ? 1 : 0)
                    .allowsHitTesting(selectedSection == .stt)
            }
            if visitedSections.contains(.llm) {
                LLMSettingsView()
                    .opacity(selectedSection == .llm ? 1 : 0)
                    .allowsHitTesting(selectedSection == .llm)
            }
            if visitedSections.contains(.models) {
                ModelSettingsView()
                    .opacity(selectedSection == .models ? 1 : 0)
                    .allowsHitTesting(selectedSection == .models)
            }
            if visitedSections.contains(.wordSets) {
                DomainWordSetsView()
                    .opacity(selectedSection == .wordSets ? 1 : 0)
                    .allowsHitTesting(selectedSection == .wordSets)
            }
            if visitedSections.contains(.history) {
                TranscriptionHistoryView()
                    .opacity(selectedSection == .history ? 1 : 0)
                    .allowsHitTesting(selectedSection == .history)
            }
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
