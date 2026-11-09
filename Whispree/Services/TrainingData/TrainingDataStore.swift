import AVFoundation
import Foundation
import OSLog
import SQLite3

/// On-disk dataset for later STT/LLM fine-tuning. Lives outside the app bundle
/// (`~/.whispree/dataset/` by default) so it survives updates and reinstalls.
///
/// NOT thread-safe: every call must happen on `TrainingDataRecorder`'s serial I/O queue
/// (tests call it directly from one thread). Schema is append-only — migrations only
/// add tables/columns, never drop.
final class TrainingDataStore {
    static let logger = Logger(subsystem: "com.whispree.app", category: "Dataset")

    static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".whispree/dataset", isDirectory: true)
    }

    static func resolveRoot(customPath: String) -> URL {
        let trimmed = customPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultRoot }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
    }

    let root: URL
    private var db: OpaquePointer?

    var audioDirectory: URL { root.appendingPathComponent("audio", isDirectory: true) }
    var screenshotDirectory: URL { root.appendingPathComponent("screenshots", isDirectory: true) }
    let databaseURL: URL

    init(root: URL, databaseFileName: String = "dataset.sqlite", walMode: Bool = true) throws {
        self.root = root
        databaseURL = root.appendingPathComponent(databaseFileName)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw StoreError.sqlite("open: \(message)")
        }
        db = handle
        try execute(walMode ? "PRAGMA journal_mode=WAL;" : "PRAGMA journal_mode=DELETE;")
        try execute("PRAGMA synchronous=NORMAL;")
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    enum StoreError: Error {
        case sqlite(String)
    }

    // MARK: - Schema

    /// Ordered forward migrations. Never edit or remove an entry — append a new one.
    static let migrations: [(version: Int, sql: String)] = [
        (1, """
        CREATE TABLE IF NOT EXISTS session (
            id TEXT PRIMARY KEY,
            created_at TEXT NOT NULL,
            record_started_at TEXT,
            record_stopped_at TEXT,
            audio_path TEXT,
            audio_format TEXT,
            audio_duration_s REAL,
            stt_provider TEXT,
            stt_model TEXT,
            stt_prompt TEXT,
            stt_text TEXT,
            stt_latency_ms INTEGER,
            stt_failure_reason TEXT,
            llm_provider TEXT,
            llm_model TEXT,
            correction_mode TEXT,
            llm_system_prompt TEXT,
            llm_output TEXT,
            llm_failure_reason TEXT,
            llm_latency_ms INTEGER,
            pasted_text TEXT,
            delivered_at TEXT,
            target_bundle_id TEXT,
            target_context_kind TEXT,
            job_terminal_status TEXT,
            job_terminal_detail TEXT,
            app_version TEXT,
            language TEXT,
            settings_snapshot TEXT
        );
        CREATE TABLE IF NOT EXISTS screenshot (
            session_id TEXT NOT NULL,
            idx INTEGER NOT NULL,
            path TEXT NOT NULL,
            captured_at TEXT,
            app_name TEXT,
            selected INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (session_id, idx)
        );
        CREATE TABLE IF NOT EXISTS edit_observation (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            status TEXT NOT NULL,
            element_role TEXT,
            before_value TEXT,
            before_selection TEXT,
            after_value TEXT,
            after_selection TEXT,
            final_value TEXT,
            ended_reason TEXT,
            started_at TEXT NOT NULL,
            ended_at TEXT
        );
        CREATE TABLE IF NOT EXISTS edit_event (
            observation_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            t_ms INTEGER NOT NULL,
            kind TEXT NOT NULL,
            value TEXT,
            value_offset INTEGER,
            PRIMARY KEY (observation_id, seq)
        );
        CREATE TABLE IF NOT EXISTS quickfix_event (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            app_bundle_id TEXT,
            selected_text TEXT,
            corrected_text TEXT,
            mode TEXT,
            dictionary_entry TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_edit_observation_session ON edit_observation(session_id);
        """),
    ]

    static var currentSchemaVersion: Int { migrations.last?.version ?? 0 }

    func schemaVersion() throws -> Int {
        var version = 0
        try query("SELECT COALESCE(MAX(version), 0) FROM schema_version;") { stmt in
            version = Int(sqlite3_column_int64(stmt, 0))
        }
        return version
    }

    private func migrate() throws {
        try execute("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL);")
        let current = try schemaVersion()
        for migration in Self.migrations where migration.version > current {
            try execute("BEGIN IMMEDIATE;")
            do {
                try execute(migration.sql)
                try run(
                    "INSERT INTO schema_version (version, applied_at) VALUES (?, ?);",
                    [.int(migration.version), .text(Self.timestamp(Date()))]
                )
                try execute("COMMIT;")
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
    }

    // MARK: - Writes

    enum Value {
        case text(String?)
        case int(Int?)
        case double(Double?)
    }

    /// Inserts a session row. Re-inserting the same id is ignored (append-only).
    func insertSession(id: String, columns: [String: Value]) throws {
        var all = columns
        all["id"] = .text(id)
        if all["created_at"] == nil { all["created_at"] = .text(Self.timestamp(Date())) }
        let keys = all.keys.sorted()
        let sql = "INSERT OR IGNORE INTO session (\(keys.joined(separator: ", "))) VALUES (\(keys.map { _ in "?" }.joined(separator: ", ")));"
        try run(sql, keys.map { all[$0]! })
    }

    func updateSession(id: String, columns: [String: Value]) throws {
        guard !columns.isEmpty else { return }
        let keys = columns.keys.sorted()
        let sql = "UPDATE session SET \(keys.map { "\($0) = ?" }.joined(separator: ", ")) WHERE id = ?;"
        try run(sql, keys.map { columns[$0]! } + [.text(id)])
    }

    func insertScreenshot(sessionID: String, index: Int, path: String, capturedAt: Date, appName: String) throws {
        try run(
            "INSERT OR IGNORE INTO screenshot (session_id, idx, path, captured_at, app_name, selected) VALUES (?, ?, ?, ?, ?, 0);",
            [.text(sessionID), .int(index), .text(path), .text(Self.timestamp(capturedAt)), .text(appName)]
        )
    }

    func markScreenshotsSelected(sessionID: String, indices: [Int]) throws {
        for index in indices {
            try run("UPDATE screenshot SET selected = 1 WHERE session_id = ? AND idx = ?;", [.text(sessionID), .int(index)])
        }
    }

    func insertObservation(id: String, sessionID: String, columns: [String: Value]) throws {
        var all = columns
        all["id"] = .text(id)
        all["session_id"] = .text(sessionID)
        let keys = all.keys.sorted()
        let sql = "INSERT OR IGNORE INTO edit_observation (\(keys.joined(separator: ", "))) VALUES (\(keys.map { _ in "?" }.joined(separator: ", ")));"
        try run(sql, keys.map { all[$0]! })
    }

    func updateObservation(id: String, columns: [String: Value]) throws {
        guard !columns.isEmpty else { return }
        let keys = columns.keys.sorted()
        let sql = "UPDATE edit_observation SET \(keys.map { "\($0) = ?" }.joined(separator: ", ")) WHERE id = ?;"
        try run(sql, keys.map { columns[$0]! } + [.text(id)])
    }

    func insertEditEvent(observationID: String, seq: Int, tMs: Int, kind: String, value: String?, valueOffset: Int?) throws {
        try run(
            "INSERT OR IGNORE INTO edit_event (observation_id, seq, t_ms, kind, value, value_offset) VALUES (?, ?, ?, ?, ?, ?);",
            [.text(observationID), .int(seq), .int(tMs), .text(kind), .text(value), .int(valueOffset)]
        )
    }

    func insertQuickFix(appBundleID: String?, selectedText: String, correctedText: String, mode: String, dictionaryEntry: String) throws {
        try run(
            "INSERT INTO quickfix_event (created_at, app_bundle_id, selected_text, corrected_text, mode, dictionary_entry) VALUES (?, ?, ?, ?, ?, ?);",
            [.text(Self.timestamp(Date())), .text(appBundleID), .text(selectedText), .text(correctedText), .text(mode), .text(dictionaryEntry)]
        )
    }

    // MARK: - Reads (stats + tests)

    func sessionCount() throws -> Int {
        var count = 0
        try query("SELECT COUNT(*) FROM session;") { count = Int(sqlite3_column_int64($0, 0)) }
        return count
    }

    /// Returns all columns of one session row as strings (nil for NULL).
    func sessionRow(id: String) throws -> [String: String?]? {
        var row: [String: String?]?
        try query("SELECT * FROM session WHERE id = ?;", [.text(id)]) { stmt in
            var values: [String: String?] = [:]
            for i in 0 ..< sqlite3_column_count(stmt) {
                let name = String(cString: sqlite3_column_name(stmt, i))
                values.updateValue(sqlite3_column_text(stmt, i).map { String(cString: $0) }, forKey: name) // keep NULL columns as nil entries
            }
            row = values
        }
        return row
    }

    func editEvents(observationID: String) throws -> [(tMs: Int, kind: String, value: String?)] {
        var events: [(Int, String, String?)] = []
        try query("SELECT t_ms, kind, value FROM edit_event WHERE observation_id = ? ORDER BY seq;", [.text(observationID)]) { stmt in
            events.append((
                Int(sqlite3_column_int64(stmt, 0)),
                String(cString: sqlite3_column_text(stmt, 1)),
                sqlite3_column_text(stmt, 2).map { String(cString: $0) }
            ))
        }
        return events
    }

    func rowCount(table: String) throws -> Int {
        var count = 0
        try query("SELECT COUNT(*) FROM \(table);") { count = Int(sqlite3_column_int64($0, 0)) }
        return count
    }

    /// Consistent snapshot of the live DB (includes un-checkpointed WAL content).
    func vacuumInto(_ destination: URL) throws {
        try run("VACUUM INTO ?;", [.text(destination.path)])
    }

    func tableNames() throws -> Set<String> {
        var names = Set<String>()
        try query("SELECT name FROM sqlite_master WHERE type = 'table';") { names.insert(String(cString: sqlite3_column_text($0, 0))) }
        return names
    }

    func totalBytes() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true { total += Int64(values?.fileSize ?? 0) }
        }
        return total
    }

    // MARK: - Files

    /// Writes 16kHz mono samples. FLAC first; 16-bit PCM WAV if FLAC encoding fails.
    /// Returns (path relative to root, format, duration seconds).
    func writeAudio(sessionID: String, samples: [Float], sampleRate: Double = 16000) throws -> (path: String, format: String, duration: Double) {
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        let duration = Double(samples.count) / sampleRate
        let flacURL = audioDirectory.appendingPathComponent("\(sessionID).flac")
        do {
            try Self.writeAudioFile(url: flacURL, samples: samples, sampleRate: sampleRate, settings: [
                AVFormatIDKey: kAudioFormatFLAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitDepthHintKey: 16,
            ])
            return ("audio/\(sessionID).flac", "flac", duration)
        } catch {
            try? FileManager.default.removeItem(at: flacURL)
            Self.logger.error("FLAC write failed, falling back to WAV: \(String(describing: error), privacy: .public)")
        }
        let wavURL = audioDirectory.appendingPathComponent("\(sessionID).wav")
        try Self.writeAudioFile(url: wavURL, samples: samples, sampleRate: sampleRate, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        return ("audio/\(sessionID).wav", "wav_pcm16", duration)
    }

    private static func writeAudioFile(url: URL, samples: [Float], sampleRate: Double, settings: [String: Any]) throws {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(samples.count, 1))),
              let channel = buffer.floatChannelData?[0]
        else { throw StoreError.sqlite("audio buffer allocation failed") }
        samples.withUnsafeBufferPointer { src in
            if let base = src.baseAddress { channel.update(from: base, count: samples.count) }
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        // Scope the file so it is closed (and the header finalized) before returning.
        do {
            let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try file.write(from: buffer)
        }
    }

    func writeScreenshot(sessionID: String, index: Int, data: Data) throws -> String {
        try FileManager.default.createDirectory(at: screenshotDirectory, withIntermediateDirectories: true)
        let name = "\(sessionID)_\(index).jpg"
        try data.write(to: screenshotDirectory.appendingPathComponent(name), options: .atomic)
        return "screenshots/\(name)"
    }

    // MARK: - Helpers

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Long values (terminal scrollback) are clipped to a window around the selection.
    /// Returns the kept text and the UTF-16 offset of its start (nil when not clipped).
    static func clip(_ value: String, around location: Int?, limit: Int = 4000) -> (text: String, offset: Int?) {
        let utf16 = value.utf16
        guard utf16.count > limit * 2 else { return (value, nil) }
        let center = min(max(location ?? utf16.count, 0), utf16.count)
        let start = max(0, min(center - limit / 2, utf16.count - limit))
        let startIndex = String.Index(utf16Offset: start, in: value)
        let endIndex = String.Index(utf16Offset: min(start + limit, utf16.count), in: value)
        return (String(value[startIndex ..< endIndex]), start)
    }

    // MARK: - SQLite primitives

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw StoreError.sqlite(message)
        }
    }

    private func prepare(_ sql: String, _ values: [Value]) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw StoreError.sqlite("prepare: \(String(cString: sqlite3_errmsg(db)))")
        }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            switch value {
            case let .text(text?): sqlite3_bind_text(stmt, index, text, -1, Self.transient)
            case let .int(number?): sqlite3_bind_int64(stmt, index, Int64(number))
            case let .double(number?): sqlite3_bind_double(stmt, index, number)
            default: sqlite3_bind_null(stmt, index)
            }
        }
        return stmt
    }

    private func run(_ sql: String, _ values: [Value]) throws {
        let stmt = try prepare(sql, values)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw StoreError.sqlite("step: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func query(_ sql: String, _ values: [Value] = [], row: (OpaquePointer?) -> Void) throws {
        let stmt = try prepare(sql, values)
        defer { sqlite3_finalize(stmt) }
        while true {
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW { row(stmt); continue }
            guard result == SQLITE_DONE else {
                throw StoreError.sqlite("query: \(String(cString: sqlite3_errmsg(db)))")
            }
            return
        }
    }
}
