import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var modelManager: ModelManager
    let onComplete: () -> Void

    @State private var currentStep = 0
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var micGranted = false
    @State private var axGranted = false
    @State private var axCheckTimer: Timer?

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { step in
                    Capsule()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            // Content
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: permissionStep
                case 2: downloadStep
                case 3: readyStep
                default: welcomeStep
                }
            }

            Spacer()
        }
        .frame(width: 480, height: 560)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Welcome to FreeWhisper")
                .font(.largeTitle.bold())

            Text("Free, local speech-to-text with AI correction.\nNo cloud. No subscription. Just your voice.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Get Started") {
                withAnimation { currentStep = 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 40)
        }
        .padding(24)
    }

    private var permissionStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("Permissions")
                .font(.title.bold())

            Text("FreeWhisper needs these permissions to work properly.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                // Microphone
                Button {
                    Task {
                        micGranted = await AudioService().requestPermission()
                        // Bring app back to front after system dialog
                        NSApp.activate(ignoringOtherApps: true)
                    }
                } label: {
                    permissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        description: "Record your voice for transcription",
                        isGranted: micGranted
                    )
                }
                .buttonStyle(.plain)

                Divider()

                // Accessibility
                Button {
                    TextInsertionService.requestAccessibilityPermission()
                    // Poll until user grants or comes back
                    startAccessibilityCheck()
                } label: {
                    permissionRow(
                        icon: "hand.raised.fill",
                        title: "Accessibility",
                        description: "Insert text into other applications",
                        isGranted: axGranted
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !micGranted || !axGranted {
                Text("Click each item to grant permission")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            navigationButtons(
                backStep: 0,
                nextStep: 2,
                nextLabel: "Continue"
            )
        }
        .padding(24)
        .onAppear {
            micGranted = AudioService().checkPermission()
            axGranted = TextInsertionService.isAccessibilityEnabled()
        }
    }

    private var downloadStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("Download Models")
                .font(.title.bold())

            Text("FreeWhisper needs AI models (~3.5 GB total).\nThis is a one-time download.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                downloadRow(
                    name: "Whisper Large V3 Turbo",
                    size: "~1.5 GB",
                    state: modelManager.whisperModelInfo.state
                )

                downloadRow(
                    name: "Qwen 2.5 3B (LLM)",
                    size: "~2.0 GB",
                    state: modelManager.llmModelInfo.state
                )
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let error = downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation { currentStep = 1 }
                }

                Spacer()

                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Downloading...")
                        .foregroundStyle(.secondary)
                } else if modelManager.whisperModelInfo.state.isReady {
                    Button("Continue") {
                        withAnimation { currentStep = 3 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button("Download All") {
                        startDownload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.bottom, 40)
        }
        .padding(24)
    }

    private var readyStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.largeTitle.bold())

            Text("Press **Control+Shift+R** to start dictating.\nYour text will appear at the cursor position.\n\nYou can change the hotkey in the dashboard.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            HStack {
                Button("Back") {
                    withAnimation { currentStep = 2 }
                }

                Spacer()

                Button("Open Dashboard") {
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 40)
        }
        .padding(24)
    }

    // MARK: - Helpers

    private func navigationButtons(backStep: Int, nextStep: Int, nextLabel: String) -> some View {
        HStack {
            Button("Back") {
                withAnimation { currentStep = backStep }
            }

            Spacer()

            Button(nextLabel) {
                withAnimation { currentStep = nextStep }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.bottom, 40)
    }

    private func permissionRow(icon: String, title: String, description: String, isGranted: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("Click to grant")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(6)
        .contentShape(Rectangle())
    }

    private func downloadRow(name: String, size: String, state: ModelState) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.headline)
                Spacer()
                Text(size).font(.caption).foregroundStyle(.secondary)
            }

            switch state {
            case .ready:
                Label("Downloaded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case .downloading(let progress):
                if progress > 0 {
                    HStack {
                        ProgressView(value: progress)
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Downloading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            case .loading:
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading model...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .error(let msg):
                Text(msg).font(.caption).foregroundStyle(.red).lineLimit(2)
            default:
                Text("Not downloaded").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func startAccessibilityCheck() {
        axCheckTimer?.invalidate()
        axCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                let granted = TextInsertionService.isAccessibilityEnabled()
                if granted {
                    axGranted = true
                    axCheckTimer?.invalidate()
                    axCheckTimer = nil
                    // Bring app back to front
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    private func startDownload() {
        isDownloading = true
        downloadError = nil

        Task {
            do {
                try await modelManager.downloadWhisperModel()
                try await modelManager.downloadLLMModel()
                withAnimation { currentStep = 3 }
            } catch {
                downloadError = error.localizedDescription
            }
            isDownloading = false
        }
    }
}
