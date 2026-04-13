import Foundation

struct SharedDictionaryConfig {
    let customURL: URL?

    var resolvedFileURL: URL? {
        if let customURL {
            return customURL.standardizedFileURL
        }
        // iCloud Drive Documents에 직접 접근 (iCloud 컨테이너 엔타이틀먼트 불필요)
        let iCloudDocs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        guard FileManager.default.fileExists(atPath: iCloudDocs.path) else { return nil }
        return iCloudDocs
            .appendingPathComponent("Whispree", isDirectory: true)
            .appendingPathComponent("domain-word-sets.json", isDirectory: false)
    }

    var statusText: String {
        customURL != nil ? "Custom sync file" : "iCloud Drive"
    }
}

enum SharedDictionaryStore {
    static func load(from url: URL) throws -> [DomainWordSet] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([DomainWordSet].self, from: data)
    }

    static func save(_ sets: [DomainWordSet], to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(sets)
        try data.write(to: url, options: .atomic)
    }
}
