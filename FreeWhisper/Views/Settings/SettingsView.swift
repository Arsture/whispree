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
        }
        .environmentObject(appState)
        .frame(width: 500, height: 400)
    }
}
