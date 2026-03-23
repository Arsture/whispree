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
        case .wordSets: return "text.book.closed"
        case .history: return "clock"
        }
    }
}

struct UnifiedView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSection: SidebarSection = .home

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 170, max: 200)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
    }

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
