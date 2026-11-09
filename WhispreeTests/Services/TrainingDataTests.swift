import AVFoundation
import SQLite3
import XCTest
@testable import Whispree

@MainActor
final class TrainingDataTests: XCTestCase {
    private static let suiteName = "com.whispree.app.tests.TrainingData"
    private var defaults: UserDefaults!
    private var root: URL!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: Self.suiteName)
        defaults.removePersistentDomain(forName: Self.suiteName)
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("whispree-dataset-tests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: Self.suiteName)
        try? FileManager.default.removeItem(at: root)
        defaults = nil
        root = nil
        super.tearDown()
    }

    private func makeSettings(enabled: Bool) -> AppSettings {
        let settings = AppSettings(store: defaults, migrateHotkeys: false)
        settings.collectTrainingData = enabled
        settings.trainingDataPath = root.path
        return settings
    }

    private func makeSnapshot() -> DictationJobSnapshot {
        DictationJobSnapshot(
            sttProviderType: .whisperKit,
            llmProviderType: .none,
            correctionMode: .standard,
            language: .korean,
            glossary: ["Whispree"]
        )
    }

    // MARK: - Schema

    func testSchemaCreatedAndMigrationIdempotent() throws {
        let store = try TrainingDataStore(root: root)
        XCTAssertEqual(try store.schemaVersion(), TrainingDataStore.currentSchemaVersion)
        XCTAssertTrue(try store.tableNames().isSuperset(of: [
            "schema_version", "session", "screenshot", "edit_observation", "edit_event", "quickfix_event",
        ]))
        try store.insertSession(id: "keep", columns: ["stt_text": .text("hello")])

        // Reopening runs migrate() again: no duplicate version rows, data kept.
        let reopened = try TrainingDataStore(root: root)
        XCTAssertEqual(try reopened.schemaVersion(), TrainingDataStore.currentSchemaVersion)
        XCTAssertEqual(try reopened.rowCount(table: "schema_version"), TrainingDataStore.migrations.count)
        XCTAssertEqual(try reopened.sessionRow(id: "keep")?["stt_text"], "hello")
    }

    func testSessionInsertUpdateRoundtrip() throws {
        let store = try TrainingDataStore(root: root)
        try store.insertSession(id: "s1", columns: ["stt_provider": .text("WhisperKit"), "audio_duration_s": .double(1.5)])
        try store.updateSession(id: "s1", columns: ["llm_output": .text("교정됨"), "llm_latency_ms": .int(120), "llm_failure_reason": .text(nil)])
        let row = try XCTUnwrap(store.sessionRow(id: "s1"))
        XCTAssertEqual(row["stt_provider"], "WhisperKit")
        XCTAssertEqual(row["llm_output"], "교정됨")
        XCTAssertEqual(row["llm_latency_ms"], "120")
        XCTAssertTrue(row.keys.contains("llm_failure_reason"))
        XCTAssertNil(row["llm_failure_reason"] ?? nil)
        XCTAssertNotNil(row["created_at"] ?? nil)
    }

    func testEditEventsKeepOrder() throws {
        let store = try TrainingDataStore(root: root)
        try store.insertObservation(id: "o1", sessionID: "s1", columns: ["status": .text("ok"), "started_at": .text("t")])
        try store.insertEditEvent(observationID: "o1", seq: 2, tMs: 1500, kind: "enter", value: nil, valueOffset: nil)
        try store.insertEditEvent(observationID: "o1", seq: 1, tMs: 1000, kind: "value", value: "abc", valueOffset: nil)
        try store.insertEditEvent(observationID: "o1", seq: 3, tMs: 2000, kind: "field_emptied", value: nil, valueOffset: nil)
        let events = try store.editEvents(observationID: "o1")
        XCTAssertEqual(events.map(\.kind), ["value", "enter", "field_emptied"])
        XCTAssertEqual(events.map(\.tMs), [1000, 1500, 2000])
        XCTAssertEqual(events.first?.value, "abc")
    }

    func testClipKeepsWindowAroundSelection() {
        let long = String(repeating: "a", count: 10000) + "MARK" + String(repeating: "b", count: 10000)
        let clipped = TrainingDataStore.clip(long, around: 10000)
        XCTAssertEqual(clipped.text.utf16.count, 4000)
        XCTAssertTrue(clipped.text.contains("MARK"))
        XCTAssertEqual(clipped.offset, 8000)
        XCTAssertNil(TrainingDataStore.clip("short", around: 0).offset)
    }

    // MARK: - Audio

    func testAudioFileWrittenWithCorrectDuration() throws {
        let store = try TrainingDataStore(root: root)
        let samples = (0 ..< 24000).map { Float(sin(Double($0) * 0.05) * 0.5) } // 1.5s @ 16kHz
        let result = try store.writeAudio(sessionID: "a1", samples: samples)
        XCTAssertTrue(["flac", "wav_pcm16"].contains(result.format))
        XCTAssertEqual(result.duration, 1.5, accuracy: 0.001)
        let file = try AVAudioFile(forReading: root.appendingPathComponent(result.path))
        XCTAssertEqual(file.fileFormat.sampleRate, 16000)
        XCTAssertEqual(file.fileFormat.channelCount, 1)
        XCTAssertEqual(Double(file.length) / file.fileFormat.sampleRate, 1.5, accuracy: 0.01)
    }

    // MARK: - Recorder

    func testRecorderNoOpWhenDisabled() {
        let settings = makeSettings(enabled: false) // recorder holds settings weakly
        let recorder = TrainingDataRecorder(settings: settings)
        XCTAssertFalse(recorder.isEnabled)
        let id = UUID()
        recorder.beginSession(
            id: id, recordStartedAt: Date(), recordStoppedAt: Date(), audio: [0.1, 0.2],
            snapshot: makeSnapshot(), targetContext: nil, screenshots: []
        )
        recorder.recordSTT(id: id, text: "x", latencyMs: 1)
        recorder.recordQuickFix(appBundleID: nil, selectedText: "a", correctedText: "b", mode: "word", dictionaryEntry: "b")
        recorder.syncTerminalStatuses { _ in .delivered }
        recorder.io.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        withExtendedLifetime(settings) {}
    }

    func testRecorderWritesSessionLifecycle() throws {
        let settings = makeSettings(enabled: true) // recorder holds settings weakly
        let recorder = TrainingDataRecorder(settings: settings)
        XCTAssertTrue(recorder.isEnabled)
        let id = UUID()
        recorder.beginSession(
            id: id, recordStartedAt: Date(), recordStoppedAt: Date(), audio: [Float](repeating: 0.1, count: 16000),
            snapshot: makeSnapshot(), targetContext: nil, screenshots: []
        )
        recorder.recordSTT(id: id, text: "원문", latencyMs: 42)
        recorder.recordDelivery(id: id, pastedText: "원문", selectedScreenshotIndices: [])
        recorder.syncTerminalStatuses { _ in .delivered }
        recorder.io.flush()

        let row = try XCTUnwrap(TrainingDataStore(root: root).sessionRow(id: id.uuidString))
        XCTAssertEqual(row["stt_text"], "원문")
        XCTAssertEqual(row["stt_latency_ms"], "42")
        XCTAssertEqual(row["pasted_text"], "원문")
        XCTAssertEqual(row["job_terminal_status"], "delivered")
        XCTAssertEqual(row["target_context_kind"], "none")
        XCTAssertEqual(row["stt_prompt"], "[\"Whispree\"]")
        let audioPath = try XCTUnwrap(row["audio_path"] ?? nil)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(audioPath).path))
        withExtendedLifetime(settings) {}
    }

    func testSettingsSnapshotExcludesSecrets() throws {
        let settings = makeSettings(enabled: true)
        settings.groqApiKey = "gsk_SECRET_GROQ"
        settings.openaiCompatibleAPIKey = "sk-SECRET_COMPAT"
        settings.openaiCompatibleBaseURL = "https://user:pw@example.com/v1"
        let json = try XCTUnwrap(TrainingDataRecorder.json(TrainingDataRecorder.settingsSnapshot(settings)))
        XCTAssertFalse(json.contains("SECRET"))
        XCTAssertFalse(json.contains("pw@"))
        XCTAssertFalse(json.lowercased().contains("apikey"))
        XCTAssertTrue(json.contains("example.com"))
    }

    // MARK: - Export

    private func seedPrivateData(_ store: TrainingDataStore) throws {
        try store.insertSession(id: "s1", columns: ["pasted_text": .text("붙여넣음")])
        _ = try store.writeAudio(sessionID: "s1", samples: [Float](repeating: 0, count: 1600))
        let shotPath = try store.writeScreenshot(sessionID: "s1", index: 0, data: Data([0xFF, 0xD8]))
        try store.insertScreenshot(sessionID: "s1", index: 0, path: shotPath, capturedAt: Date(), appName: "Notes")
        try store.insertObservation(id: "o1", sessionID: "s1", columns: [
            "status": .text("ok"), "before_value": .text("PRIVATE before"), "after_value": .text("PRIVATE after"),
            "final_value": .text("PRIVATE final"), "started_at": .text("t"),
        ])
        try store.insertEditEvent(observationID: "o1", seq: 1, tMs: 10, kind: "value", value: "PRIVATE event", valueOffset: 3)
    }

    func testExportCopyStripsPrivateDataAndLeavesLiveDBUntouched() throws {
        let store = try TrainingDataStore(root: root)
        try seedPrivateData(store)
        let copyDir = root.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: copyDir, withIntermediateDirectories: true)
        let copyURL = copyDir.appendingPathComponent("dataset.sqlite")

        try TrainingDataExporter.makeDatabaseCopy(from: store, to: copyURL, includePrivate: false)

        let copy = try TrainingDataStore(root: copyDir, walMode: false)
        XCTAssertEqual(try copy.rowCount(table: "screenshot"), 0)
        XCTAssertEqual(try copy.rowCount(table: "edit_observation"), 1)
        XCTAssertEqual(try copy.editEvents(observationID: "o1").first?.value, .some(nil))
        XCTAssertEqual(try copy.sessionRow(id: "s1")?["pasted_text"], "붙여넣음")
        XCTAssertFalse(try String(contentsOf: copyURL, encoding: .isoLatin1).contains("PRIVATE"))

        // Live DB still has everything.
        XCTAssertEqual(try store.rowCount(table: "screenshot"), 1)
        XCTAssertEqual(try store.editEvents(observationID: "o1").first?.value, "PRIVATE event")
    }

    func testExportCopyKeepsPrivateDataWhenIncluded() throws {
        let store = try TrainingDataStore(root: root)
        try seedPrivateData(store)
        let copyDir = root.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: copyDir, withIntermediateDirectories: true)
        let copyURL = copyDir.appendingPathComponent("dataset.sqlite")
        try TrainingDataExporter.makeDatabaseCopy(from: store, to: copyURL, includePrivate: true)
        let copy = try TrainingDataStore(root: copyDir, walMode: false)
        XCTAssertEqual(try copy.rowCount(table: "screenshot"), 1)
        XCTAssertEqual(try copy.editEvents(observationID: "o1").first?.value, "PRIVATE event")
    }

    func testManifestContents() throws {
        let store = try TrainingDataStore(root: root)
        try seedPrivateData(store)
        let copyDir = root.appendingPathComponent("export", isDirectory: true)
        try FileManager.default.createDirectory(at: copyDir, withIntermediateDirectories: true)
        let copyURL = copyDir.appendingPathComponent("dataset.sqlite")
        try TrainingDataExporter.makeDatabaseCopy(from: store, to: copyURL, includePrivate: false)

        let manifest = try TrainingDataExporter.makeManifest(databaseCopy: copyURL, appVersion: "9.9 (1)", includePrivate: false)
        XCTAssertEqual(manifest.appVersion, "9.9 (1)")
        XCTAssertEqual(manifest.schemaVersion, TrainingDataStore.currentSchemaVersion)
        XCTAssertFalse(manifest.includesScreenshots)
        XCTAssertFalse(manifest.includesFieldLogs)
        XCTAssertEqual(manifest.rowCounts["session"], 1)
        XCTAssertEqual(manifest.rowCounts["screenshot"], 0)
        XCTAssertEqual(manifest.rowCounts["edit_event"], 1)
        XCTAssertFalse(manifest.exportedAt.isEmpty)
    }

    func testFullExportProducesZipWithoutScreenshotsByDefault() throws {
        let store = try TrainingDataStore(root: root)
        try seedPrivateData(store)
        let zipURL = root.appendingPathComponent("out/whispree-dataset-test.zip")
        try FileManager.default.createDirectory(at: zipURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try TrainingDataExporter.export(store: store, to: zipURL, includePrivate: false, appVersion: "t")

        let listing = Process()
        let pipe = Pipe()
        listing.executableURL = URL(fileURLWithPath: "/usr/bin/zipinfo")
        listing.arguments = ["-1", zipURL.path]
        listing.standardOutput = pipe
        try listing.run()
        listing.waitUntilExit()
        let names = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertTrue(names.contains("whispree-dataset-test/dataset.sqlite"))
        XCTAssertTrue(names.contains("whispree-dataset-test/manifest.json"))
        XCTAssertTrue(names.contains("whispree-dataset-test/audio/s1."))
        XCTAssertFalse(names.contains("screenshots"))
        XCTAssertFalse(names.contains("-wal"))
    }
}
