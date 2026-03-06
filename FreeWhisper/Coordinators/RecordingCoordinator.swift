import Foundation
import AppKit
import Combine

@MainActor
final class RecordingCoordinator: ObservableObject {
    private let appState: AppState
    private let audioService: AudioService
    private let sttService: STTService
    private let llmService: LLMService
    private let textInsertionService: TextInsertionService

    private var currentTask: Task<Void, Never>?
    private var levelCancellable: AnyCancellable?
    private var previousApp: NSRunningApplication?

    init(
        appState: AppState,
        audioService: AudioService,
        sttService: STTService,
        llmService: LLMService,
        textInsertionService: TextInsertionService
    ) {
        self.appState = appState
        self.audioService = audioService
        self.sttService = sttService
        self.llmService = llmService
        self.textInsertionService = textInsertionService

        // Pipe audio level to appState for UI
        levelCancellable = audioService.$currentLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak appState] level in
                appState?.currentAudioLevel = level
            }
    }

    func startRecording() {
        guard appState.transcriptionState == .idle else { return }
        guard sttService.isReady else {
            appState.currentError = .sttError("Model is not ready yet. Please wait for model download to complete.")
            return
        }

        // Remember the app the user was typing in before recording
        previousApp = NSWorkspace.shared.frontmostApplication

        do {
            try audioService.startRecording()
            appState.transcriptionState = .recording
            appState.isRecording = true
            appState.partialText = ""
            appState.finalText = ""
            appState.correctedText = ""
        } catch {
            appState.currentError = .sttError("Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        guard appState.transcriptionState == .recording else { return }

        let audioBuffer = audioService.stopRecording()
        appState.isRecording = false

        // Check for empty audio
        guard !audioBuffer.isEmpty else {
            appState.transcriptionState = .idle
            return
        }

        // Check if audio has any significant content
        let maxAmplitude = audioBuffer.map { abs($0) }.max() ?? 0
        guard maxAmplitude > 0.01 else {
            appState.transcriptionState = .idle
            return
        }

        currentTask = Task {
            await processPipeline(audioBuffer: audioBuffer)
        }
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        if audioService.isRecording {
            _ = audioService.stopRecording()
        }
        appState.transcriptionState = .idle
        appState.isRecording = false
    }

    // MARK: - Pipeline

    private func processPipeline(audioBuffer: [Float]) async {
        // Step 1: Transcribe
        appState.transcriptionState = .transcribing

        do {
            let transcribedText = try await sttService.transcribe(
                audioBuffer: audioBuffer,
                language: appState.settings.language
            )

            guard !Task.isCancelled else { return }

            appState.finalText = transcribedText

            // Step 2: LLM Correction (if enabled)
            var textToInsert = transcribedText

            if appState.settings.isLLMEnabled && llmService.isReady {
                appState.transcriptionState = .correcting

                do {
                    let prompt: String?
                    switch appState.settings.correctionMode {
                    case .custom:
                        prompt = appState.settings.customLLMPrompt
                    case .standard, .promptEngineering:
                        prompt = CorrectionPrompts.prompt(
                            for: appState.settings.correctionMode,
                            language: appState.settings.language
                        )
                    }
                    let corrected = try await llmService.correct(
                        text: transcribedText,
                        customPrompt: prompt
                    )
                    guard !Task.isCancelled else { return }
                    appState.correctedText = corrected
                    textToInsert = corrected
                } catch {
                    // LLM failure is non-fatal - use raw transcription
                    appState.correctedText = ""
                    textToInsert = transcribedText
                }
            }

            // Step 3: Insert text into the original app
            guard !Task.isCancelled else { return }
            appState.transcriptionState = .inserting

            let success = textInsertionService.insertText(textToInsert, targetApp: previousApp)
            if !success {
                // Copy to clipboard as last resort
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textToInsert, forType: .string)
            }

            // Record in history
            appState.addToHistory(
                original: transcribedText,
                corrected: appState.correctedText.isEmpty ? nil : appState.correctedText
            )

        } catch {
            appState.currentError = .sttError(error.localizedDescription)
        }

        appState.transcriptionState = .idle
    }
}
