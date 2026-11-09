import Foundation
import SQLite3

/// Contents of `manifest.json` at the root of an exported dataset zip.
struct TrainingDataManifest: Codable, Equatable {
    let appVersion: String
    let schemaVersion: Int
    let exportedAt: String
    let includesScreenshots: Bool
    let includesFieldLogs: Bool
    let rowCounts: [String: Int]
}

/// Builds a shareable zip of the dataset. Runs on `TrainingDataRecorder`'s I/O queue.
///
/// Privacy default: screenshots and raw edit-observation field values are excluded.
/// Exclusions are applied to a temp copy made with `VACUUM INTO` — never to the live DB.
enum TrainingDataExporter {
    static let exportedTables = ["session", "screenshot", "edit_observation", "edit_event", "quickfix_event"]

    /// Writes a consistent copy of the live DB to `destination` and strips private data
    /// from the copy unless `includePrivate` is true.
    static func makeDatabaseCopy(from store: TrainingDataStore, to destination: URL, includePrivate: Bool) throws {
        try? FileManager.default.removeItem(at: destination)
        try store.vacuumInto(destination)
        var db: OpaquePointer?
        guard sqlite3_open_v2(destination.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else {
            sqlite3_close(db)
            throw TrainingDataStore.StoreError.sqlite("open export copy failed")
        }
        defer { sqlite3_close(db) }
        let strip = includePrivate ? "" : """
        DELETE FROM screenshot;
        UPDATE edit_observation SET before_value = NULL, before_selection = NULL,
            after_value = NULL, after_selection = NULL, final_value = NULL;
        UPDATE edit_event SET value = NULL, value_offset = NULL;
        """
        let sql = strip + "PRAGMA journal_mode=DELETE; VACUUM;"
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw TrainingDataStore.StoreError.sqlite("strip export copy: \(message)")
        }
    }

    static func makeManifest(databaseCopy: URL, appVersion: String, includePrivate: Bool, now: Date = Date()) throws -> TrainingDataManifest {
        let copy = try TrainingDataStore(root: databaseCopy.deletingLastPathComponent(), databaseFileName: databaseCopy.lastPathComponent, walMode: false)
        var counts: [String: Int] = [:]
        for table in exportedTables {
            counts[table] = try copy.rowCount(table: table)
        }
        return TrainingDataManifest(
            appVersion: appVersion,
            schemaVersion: try copy.schemaVersion(),
            exportedAt: TrainingDataStore.timestamp(now),
            includesScreenshots: includePrivate,
            includesFieldLogs: includePrivate,
            rowCounts: counts
        )
    }

    /// Stages DB copy + audio (+ screenshots) + manifest in a temp folder and zips it with ditto.
    @discardableResult
    static func export(store: TrainingDataStore, to zipURL: URL, includePrivate: Bool, appVersion: String) throws -> TrainingDataManifest {
        let fm = FileManager.default
        let folderName = zipURL.deletingPathExtension().lastPathComponent
        let workDir = fm.temporaryDirectory.appendingPathComponent("whispree-export-\(UUID().uuidString)", isDirectory: true)
        let staging = workDir.appendingPathComponent(folderName, isDirectory: true)
        defer { try? fm.removeItem(at: workDir) }
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)

        let dbCopy = staging.appendingPathComponent("dataset.sqlite")
        try makeDatabaseCopy(from: store, to: dbCopy, includePrivate: includePrivate)
        let manifest = try makeManifest(databaseCopy: dbCopy, appVersion: appVersion, includePrivate: includePrivate)

        if fm.fileExists(atPath: store.audioDirectory.path) {
            try fm.copyItem(at: store.audioDirectory, to: staging.appendingPathComponent("audio"))
        }
        if includePrivate, fm.fileExists(atPath: store.screenshotDirectory.path) {
            try fm.copyItem(at: store.screenshotDirectory, to: staging.appendingPathComponent("screenshots"))
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: staging.appendingPathComponent("manifest.json"))

        try? fm.removeItem(at: zipURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", staging.path, zipURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw TrainingDataStore.StoreError.sqlite("ditto exited with \(process.terminationStatus)")
        }
        return manifest
    }

    static func defaultFileName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "whispree-dataset-\(formatter.string(from: now)).zip"
    }
}
