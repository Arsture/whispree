import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            STTSettingsView()
                .tabItem {
                    Label("STT", systemImage: "mic.fill")
                }

            LLMSettingsView()
                .tabItem {
                    Label("LLM", systemImage: "text.badge.checkmark")
                }

            ModelSettingsView()
                .tabItem {
                    Label("모델", systemImage: "arrow.down.circle")
                }

            DomainWordSetsView()
                .tabItem {
                    Label("단어 사전", systemImage: "text.book.closed")
                }
        }
        .environmentObject(appState)
        .frame(width: 500, height: 480)
    }
}
