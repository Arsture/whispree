import Sparkle
import SwiftUI

@main
struct WhispreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        Settings {
            Color.clear
                .frame(width: 0, height: 0)
                .onAppear {
                    // Cmd+, → 설정 윈도우 대신 메인 윈도우 표시
                    DispatchQueue.main.async {
                        NSApp.keyWindow?.close()
                        appDelegate.showMainWindow()
                    }
                }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates...", action: viewModel.updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

final class CheckForUpdatesViewModel: ObservableObject {
    let updater: SPUUpdater
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        self.updater = updater
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
