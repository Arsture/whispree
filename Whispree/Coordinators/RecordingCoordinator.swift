import AppKit
import Combine
import Foundation

@MainActor
final class RecordingCoordinator: ObservableObject {
    private let appState: AppState
    private let audioService: AudioService
    private let textInsertionService: TextInsertionService

    private var currentTask: Task<Void, Never>?
    private var levelCancellable: AnyCancellable?
    private var bandsCancellable: AnyCancellable?
    private var workspaceObserver: AnyCancellable?
    private var previousApp: NSRunningApplication?
    private var lastExternalApp: NSRunningApplication?
    private let continuousCapture = ContinuousScreenCaptureService()

    init(
        appState: AppState,
        audioService: AudioService,
        textInsertionService: TextInsertionService
    ) {
        self.appState = appState
        self.audioService = audioService
        self.textInsertionService = textInsertionService

        // Pipe audio level + frequency bands to appState for UI
        levelCancellable = audioService.$currentLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak appState] level in
                appState?.currentAudioLevel = level
            }

        bandsCancellable = audioService.$frequencyBands
            .receive(on: DispatchQueue.main)
            .sink { [weak appState] bands in
                appState?.frequencyBands = bands
            }

        // Track last non-Whispree frontmost app for text insertion
        workspaceObserver = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
                Task { @MainActor [weak self] in
                    self?.lastExternalApp = app
                }
            }
    }

    func startRecording() {
        // 이전 파이프라인이 stuck 상태면 강제 리셋 (transcribing/correcting/inserting에서 멈춘 경우)
        if appState.transcriptionState != .idle, appState.transcriptionState != .recording {
            currentTask?.cancel()
            currentTask = nil
            appState.transcriptionState = .idle
        }
        guard appState.transcriptionState == .idle else { return }
        guard let sttProvider = appState.sttProvider else {
            appState.currentError = .sttError("STT 프로바이더가 설정되지 않았습니다.")
            return
        }
        let sttValidation = sttProvider.validate()
        guard sttValidation.isValid else {
            appState.currentError = .sttError(sttValidation.message)
            return
        }

        // Remember the app the user was typing in before recording
        // If Whispree is frontmost (user clicked menu bar), use last tracked external app
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier == Bundle.main.bundleIdentifier {
            previousApp = lastExternalApp
        } else {
            previousApp = frontmost
        }

        // 연속 스크린샷 캡처 시작 (Vision 지원 프로바이더 + 토글 ON일 때)
        if appState.settings.isScreenshotContextEnabled,
           appState.llmProvider?.supportsVision == true
        {
            appState.capturedScreenshots = []
            continuousCapture.onCapture = { [weak appState] screenshot in
                appState?.capturedScreenshots.append(screenshot)
            }
            continuousCapture.startMonitoring()
        }

        do {
            try audioService.startRecording(channelSelection: appState.settings.audioInputChannel)
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

        // 연속 캡처 중지 — 마지막 pending debounce flush
        let screenshots = continuousCapture.stopMonitoring()

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
        continuousCapture.reset()
        if audioService.isRecording {
            _ = audioService.stopRecording()
        }
        appState.transcriptionState = .idle
        appState.isRecording = false
    }

    // MARK: - Pipeline

    private func processPipeline(audioBuffer: [Float]) async {
        // Step 1: Transcribe via STT Provider
        appState.transcriptionState = .transcribing

        defer {
            appState.transcriptionState = .idle
        }

        do {
            guard let sttProvider = appState.sttProvider else {
                appState.currentError = .sttError("No STT provider configured")
                return
            }

            // 도메인 단어 세트를 Provider에 설정 (transcribe 시 내부에서 tokenize)
            if let whisperProvider = sttProvider as? WhisperKitProvider {
                whisperProvider.domainWordSets = appState.settings.domainWordSets
            }

            let result = try await sttProvider.transcribe(
                audioBuffer: audioBuffer,
                language: appState.settings.language == .auto ? nil : appState.settings.language,
                promptTokens: nil
            )

            guard !Task.isCancelled else { return }

            let transcribedText = result.text
            appState.finalText = transcribedText

            // Step 2: LLM Correction via LLM Provider
            var textToInsert = transcribedText

            if let llmProvider = appState.llmProvider, llmProvider.isReady,
               !(llmProvider is NoneProvider)
            {
                appState.transcriptionState = .correcting

                do {
                    var systemPrompt: String = switch appState.settings.correctionMode {
                        case .custom:
                            appState.settings.customLLMPrompt ?? CorrectionPrompts.codeSwitchPrompt
                        case .standard, .fillerRemoval, .structured:
                            CorrectionPrompts.prompt(
                                for: appState.settings.correctionMode,
                                language: appState.settings.language
                            )
                    }

                    // 교정 매핑 주입 (항상, correction mode와 무관)
                    let corrections = appState.settings.domainWordSets
                        .filter(\.isEnabled)
                        .flatMap(\.corrections)
                    if !corrections.isEmpty {
                        let mappingText = corrections.map { "\($0.from) → \($0.to)" }.joined(separator: "\n")
                        systemPrompt += "\n\n교정 매핑 (왼쪽 표현이 텍스트에 있으면 오른쪽으로 교정):\n" + mappingText
                    }

                    // 스크린샷 맥락 프롬프트 주입
                    let screenshotData = appState.capturedScreenshots.map(\.imageData)
                    if !screenshotData.isEmpty {
                        systemPrompt += CorrectionPrompts.screenshotContextPrompt
                    }

                    // 활성화된 도메인 단어 세트에서 glossary 생성
                    let glossary = appState.settings.domainWordSets
                        .filter(\.isEnabled)
                        .flatMap(\.words)

                    let corrected = try await llmProvider.correct(
                        text: transcribedText,
                        systemPrompt: systemPrompt,
                        glossary: glossary.isEmpty ? nil : glossary,
                        screenshots: screenshotData
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

            // Step 3: 스크린샷 선택 (텍스트 삽입 전에 — 포커스 이동 문제 방지)
            guard !Task.isCancelled else { return }
            var selectedImages: [Data] = []
            if appState.settings.hasCompletedOnboarding,
               appState.settings.isScreenshotPasteEnabled,
               !appState.capturedScreenshots.isEmpty
            {
                appState.transcriptionState = .selectingScreenshots

                selectedImages = await withCheckedContinuation { continuation in
                    appState.screenshotSelectionCallback = { selected in
                        continuation.resume(returning: selected)
                    }
                }
                appState.screenshotSelectionCallback = nil
            }

            // Step 4: 텍스트 삽입 → 대상 앱으로 포커스 이동 (선택 결과와 무관하게 항상 실행)
            guard !Task.isCancelled else { return }
            if appState.settings.hasCompletedOnboarding {
                appState.transcriptionState = .inserting

                let success = await textInsertionService.insertText(textToInsert, targetApp: previousApp)
                if !success {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(textToInsert, forType: .string)
                }

                // Step 5: 선택된 이미지 붙여넣기
                if !selectedImages.isEmpty, !Task.isCancelled {
                    await textInsertionService.insertImages(selectedImages, targetApp: previousApp)
                }
            }

            // Record in history
            appState.addToHistory(
                original: transcribedText,
                corrected: appState.correctedText.isEmpty ? nil : appState.correctedText
            )

        } catch {
            appState.currentError = .sttError(error.localizedDescription)
        }
    }
}
