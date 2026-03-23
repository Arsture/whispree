import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            LLMSettingsView()
                .tabItem {
                    Label("LLM", systemImage: "text.badge.checkmark")
                }

            ModelSettingsView()
                .tabItem {
                    Label("Models", systemImage: "arrow.down.circle")
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
