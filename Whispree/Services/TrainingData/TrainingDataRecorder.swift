import AppKit
import Foundation

/// Serial I/O lane for the dataset. Owns the lazily opened store; every disk/SQLite
/// operation runs on `queue` so recording and FIFO delivery are never blocked.
final class TrainingDataIO: @unchecked Sendable {
    let queue = DispatchQueue(label: "com.whispree.app.dataset", qos: .utility)
    private var store: TrainingDataStore?

    /// Runs `work` on the I/O queue with a store opened at `root`. Errors are logged and swallowed.
    func perform(root: URL, _ label: String, _ work: @escaping (TrainingDataStore) throws -> Void) {
        queue.async { [self] in
            do {
                try work(openStore(root: root))
            } catch {
                TrainingDataStore.logger.error("\(label, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Must be called on `queue`.
    func openStore(root: URL) throws -> TrainingDataStore {
        if let store, store.root.standardizedFileURL == root.standardizedFileURL { return store }
        let opened = try TrainingDataStore(root: root)
        store = opened
        return opened
    }

    /// Blocks until queued work finished (tests only).
    func flush() {
        queue.sync {}
    }
}

/// Local-only training-data collection facade. Every method is a cheap no-op when
/// `AppSettings.collectTrainingData` is off. Collect raw now, judge later — no labels here.
@MainActor
final class TrainingDataRecorder {
    static let shared = TrainingDataRecorder()

    weak var settings: AppSettings?
    let io = TrainingDataIO()
    /// Sessions begun while collection was on. Later updates only touch these.
    private var openSessions = Set<UUID>()
    private(set) var activeObservation: EditObservation?

    init(settings: AppSettings? = nil) {
        self.settings = settings
    }

    var isEnabled: Bool { settings?.collectTrainingData == true }

    var root: URL {
        TrainingDataStore.resolveRoot(customPath: settings?.trainingDataPath ?? "")
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - Session lifecycle

    func beginSession(
        id: UUID,
        recordStartedAt: Date?,
        recordStoppedAt: Date,
        audio: [Float],
        snapshot: DictationJobSnapshot,
        targetContext: ExternalContext?,
        screenshots: [CapturedScreenshot]
    ) {
        guard isEnabled, let settings else { return }
        openSessions.insert(id)
        let sessionID = id.uuidString
        let shots = screenshots.map { ($0.timestamp, $0.appName, $0.imageData) }
        var columns: [String: TrainingDataStore.Value] = [
            "record_started_at": .text(recordStartedAt.map(TrainingDataStore.timestamp)),
            "record_stopped_at": .text(TrainingDataStore.timestamp(recordStoppedAt)),
            "stt_provider": .text(snapshot.sttProviderType.rawValue),
            "stt_model": .text(Self.sttModelName(settings: settings, type: snapshot.sttProviderType)),
            "stt_prompt": .text(Self.json(snapshot.glossary)),
            "correction_mode": .text(snapshot.correctionMode.rawValue),
            "language": .text(snapshot.language.rawValue),
            "target_bundle_id": .text(targetContext?.app.bundleIdentifier),
            "target_context_kind": .text(Self.contextKind(targetContext)),
            "app_version": .text(Self.appVersion),
            "settings_snapshot": .text(Self.json(Self.settingsSnapshot(settings))),
        ]
        io.perform(root: root, "beginSession") { store in
            if let audioFile = try? store.writeAudio(sessionID: sessionID, samples: audio) {
                columns["audio_path"] = .text(audioFile.path)
                columns["audio_format"] = .text(audioFile.format)
                columns["audio_duration_s"] = .double(audioFile.duration)
            } else {
                TrainingDataStore.logger.error("audio write failed session=\(sessionID, privacy: .public)")
            }
            try store.insertSession(id: sessionID, columns: columns)
            for (index, shot) in shots.enumerated() {
                let path = try store.writeScreenshot(sessionID: sessionID, index: index, data: shot.2)
                try store.insertScreenshot(sessionID: sessionID, index: index, path: path, capturedAt: shot.0, appName: shot.1)
            }
        }
    }

    func recordSTT(id: UUID, text: String?, latencyMs: Int, failureReason: String? = nil) {
        update(id, "recordSTT", [
            "stt_text": .text(text),
            "stt_latency_ms": .int(latencyMs),
            "stt_failure_reason": .text(failureReason),
        ])
    }

    /// `provider` nil means the LLM stage never ran a provider (fallback before calling it).
    func recordLLM(id: UUID, provider: String?, systemPrompt: String?, output: String?, failureReason: String?, latencyMs: Int?) {
        guard let settings else { return }
        update(id, "recordLLM", [
            "llm_provider": .text(provider ?? settings.llmProviderType.rawValue),
            "llm_model": .text(Self.llmModelName(settings: settings)),
            "llm_system_prompt": .text(systemPrompt),
            "llm_output": .text(output),
            "llm_failure_reason": .text(failureReason),
            "llm_latency_ms": .int(latencyMs),
        ])
    }

    func recordDelivery(id: UUID, pastedText: String, selectedScreenshotIndices: [Int]) {
        guard openSessions.contains(id) else { return }
        update(id, "recordDelivery", [
            "pasted_text": .text(pastedText),
            "delivered_at": .text(TrainingDataStore.timestamp(Date())),
        ])
        guard !selectedScreenshotIndices.isEmpty else { return }
        let sessionID = id.uuidString
        io.perform(root: root, "markScreenshots") { store in
            try store.markScreenshotsSelected(sessionID: sessionID, indices: selectedScreenshotIndices)
        }
    }

    /// Records terminal status for open sessions whose job reached a terminal state (or vanished).
    func syncTerminalStatuses(status: (UUID) -> DictationJobStatus?) {
        guard !openSessions.isEmpty else { return }
        for id in openSessions {
            let current = status(id)
            guard current?.isTerminal ?? true else { continue }
            openSessions.remove(id)
            let (name, detail) = Self.terminalName(current)
            update(id, "terminal", ["job_terminal_status": .text(name), "job_terminal_detail": .text(detail)], force: true)
        }
    }

    // MARK: - Edit observation

    /// Call right before the paste keystroke. Ends any running observation (`next_delivery`).
    func prepareEditObservation(sessionID: UUID, app: NSRunningApplication?) {
        activeObservation?.stop(.nextDelivery)
        activeObservation = nil
        guard isEnabled, openSessions.contains(sessionID), let app,
              app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        let observation = EditObservation(sessionID: sessionID.uuidString, app: app, sink: makeSink(sessionID: sessionID.uuidString))
        observation.onFinish = { [weak self, weak observation] in
            guard let self, let observation, activeObservation === observation else { return }
            activeObservation = nil
            Self.setMarkerTap(nil)
        }
        activeObservation = observation
    }

    /// Call right after the paste keystroke was posted.
    func pasteDidHappen() {
        guard let observation = activeObservation else { return }
        Self.setMarkerTap { [weak observation] kind in observation?.marker(kind.rawValue) }
        observation.start()
    }

    /// Delivery failed before paste: drop the prepared observation.
    func cancelPreparedObservation() {
        activeObservation?.stop(.error)
    }

    private static func setMarkerTap(_ handler: ((EventTapHotkeyService.EditMarker) -> Void)?) {
        let tap = EventTapHotkeyService.shared
        tap.onEditMarker = handler
        tap.isEditObservationActive = handler != nil
    }

    private func makeSink(sessionID: String) -> EditObservation.Sink {
        let io = io
        let root = root
        return EditObservation.Sink(
            begin: { id, status, role, before, startedAt in
                let clipped = before.map { TrainingDataStore.clip($0.value, around: $0.selection?.location) }
                io.perform(root: root, "observation.begin") { store in
                    try store.insertObservation(id: id, sessionID: sessionID, columns: [
                        "status": .text(status.rawValue),
                        "element_role": .text(role),
                        "before_value": .text(clipped?.text),
                        "before_selection": .text(before?.selectionText),
                        "started_at": .text(TrainingDataStore.timestamp(startedAt)),
                    ])
                }
            },
            after: { id, snapshot in
                let clipped = snapshot.map { TrainingDataStore.clip($0.value, around: $0.selection?.location) }
                io.perform(root: root, "observation.after") { store in
                    try store.updateObservation(id: id, columns: [
                        "after_value": .text(clipped?.text),
                        "after_selection": .text(snapshot?.selectionText),
                    ])
                }
            },
            event: { id, seq, tMs, kind, value in
                let clipped = value.map { TrainingDataStore.clip($0.value, around: $0.selection?.location) }
                io.perform(root: root, "observation.event") { store in
                    try store.insertEditEvent(observationID: id, seq: seq, tMs: tMs, kind: kind, value: clipped?.text, valueOffset: clipped?.offset)
                }
            },
            end: { id, finalValue, reason, endedAt in
                let clipped = finalValue.map { TrainingDataStore.clip($0, around: nil) }
                io.perform(root: root, "observation.end") { store in
                    try store.updateObservation(id: id, columns: [
                        "final_value": .text(clipped?.text),
                        "ended_reason": .text(reason.rawValue),
                        "ended_at": .text(TrainingDataStore.timestamp(endedAt)),
                    ])
                }
            }
        )
    }

    // MARK: - Quick Fix

    func recordQuickFix(appBundleID: String?, selectedText: String, correctedText: String, mode: String, dictionaryEntry: String) {
        guard isEnabled else { return }
        io.perform(root: root, "quickfix") { store in
            try store.insertQuickFix(
                appBundleID: appBundleID,
                selectedText: selectedText,
                correctedText: correctedText,
                mode: mode,
                dictionaryEntry: dictionaryEntry
            )
        }
    }

    // MARK: - Stats / export

    func stats() async -> (sessions: Int, bytes: Int64) {
        let root = root
        let io = io
        return await withCheckedContinuation { continuation in
            io.queue.async {
                guard FileManager.default.fileExists(atPath: root.appendingPathComponent("dataset.sqlite").path),
                      let store = try? io.openStore(root: root)
                else { return continuation.resume(returning: (0, 0)) }
                continuation.resume(returning: ((try? store.sessionCount()) ?? 0, store.totalBytes()))
            }
        }
    }

    func export(to zipURL: URL, includePrivate: Bool) async throws -> TrainingDataManifest {
        let root = root
        let io = io
        let version = Self.appVersion
        return try await withCheckedThrowingContinuation { continuation in
            io.queue.async {
                continuation.resume(with: Result {
                    try TrainingDataExporter.export(
                        store: io.openStore(root: root),
                        to: zipURL,
                        includePrivate: includePrivate,
                        appVersion: version
                    )
                })
            }
        }
    }

    // MARK: - Helpers

    private func update(_ id: UUID, _ label: String, _ columns: [String: TrainingDataStore.Value], force: Bool = false) {
        guard force || openSessions.contains(id) else { return }
        let sessionID = id.uuidString
        io.perform(root: root, label) { store in
            try store.updateSession(id: sessionID, columns: columns)
        }
    }

    static func contextKind(_ context: ExternalContext?) -> String {
        switch context {
        case .chromeTab: "chrome"
        case .iTerm2Session: "iterm2"
        case .app: "app"
        case nil: "none"
        }
    }

    static func terminalName(_ status: DictationJobStatus?) -> (String, String?) {
        switch status {
        case .delivered: ("delivered", nil)
        case .copiedToClipboard: ("copied_to_clipboard", nil)
        case let .failed(message): ("failed", message)
        case .canceled: ("canceled", nil)
        case .skipped: ("skipped", nil)
        case nil: ("pruned", nil)
        default: ("unknown", nil)
        }
    }

    static func sttModelName(settings: AppSettings, type: STTProviderType) -> String {
        switch type {
        case .whisperKit: settings.whisperModelId
        case .mlxAudio: settings.mlxAudioModelId
        case .groq: "whisper-large-v3-turbo"
        }
    }

    static func llmModelName(settings: AppSettings) -> String? {
        switch settings.llmProviderType {
        case .none: nil
        case .local: settings.llmModelId
        case .openai: settings.openaiModel
        case .groq: settings.groqLLMModel.rawValue
        case .openaiCompatible: settings.openaiCompatibleModelId
        }
    }

    /// Non-secret settings relevant to reproducing a session. NEVER include API keys/tokens.
    static func settingsSnapshot(_ settings: AppSettings) -> [String: String] {
        [
            "recordingMode": settings.recordingMode.rawValue,
            "language": settings.language.rawValue,
            "isLLMEnabled": String(settings.isLLMEnabled),
            "correctionMode": settings.correctionMode.rawValue,
            "customLLMPrompt": settings.customLLMPrompt ?? "",
            "whisperModelId": settings.whisperModelId,
            "llmModelId": settings.llmModelId,
            "mlxAudioModelId": settings.mlxAudioModelId,
            "sttProviderType": settings.sttProviderType.rawValue,
            "llmProviderType": settings.llmProviderType.rawValue,
            "openaiModel": settings.openaiModel,
            "openaiReasoningEffort": settings.openaiReasoningEffort,
            "groqLLMModel": settings.groqLLMModel.rawValue,
            "openaiCompatibleHost": URL(string: settings.openaiCompatibleBaseURL)?.host ?? "",
            "openaiCompatibleModelId": settings.openaiCompatibleModelId,
            "openaiCompatibleSupportsVision": String(settings.openaiCompatibleSupportsVision),
            "isScreenshotContextEnabled": String(settings.isScreenshotContextEnabled),
            "isScreenshotPasteEnabled": String(settings.isScreenshotPasteEnabled),
            "vadEnabled": String(settings.vadEnabled),
            "audioInputChannel": String(settings.audioInputChannel),
            "restoreBrowserTab": String(settings.restoreBrowserTab),
            "restoreTerminalContext": String(settings.restoreTerminalContext),
        ]
    }

    static func json(_ value: some Encodable) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }
}
