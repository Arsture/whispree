import Foundation

struct SharedDictionaryConfig {
    let customURL: URL?

    var resolvedFileURL: URL? {
        if let customURL {
            return customURL.standardizedFileURL
        }
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Whispree", isDirectory: true)
            .appendingPathComponent("domain-word-sets.json", isDirectory: false)
    }

    var statusText: String {
        if customURL != nil {
            return "Custom sync file"
        }
        return "iCloud Drive"
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
