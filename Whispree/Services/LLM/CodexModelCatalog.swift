import Foundation

/// Codex CLI가 노출하는 모델 한 개. `~/.codex/models_cache.json`의 `models[]` 항목에서 필요한 필드만 추린 것.
struct CodexModel: Equatable, Identifiable, Sendable {
    let slug: String
    let displayName: String
    let description: String
    let supportsVision: Bool
    /// 서버가 허용하는 reasoning effort 목록. 비어 있으면 요청에서 `reasoning` 필드를 생략한다.
    let supportedEfforts: [String]

    var id: String { slug }

    /// 받아쓰기 교정은 빨라야 하므로 허용 목록 중 가장 낮은 effort를 쓴다.
    var lowestEffort: String? {
        CodexModelCatalog.lowestEffort(in: supportedEfforts)
    }
}

/// Codex CLI의 모델 캐시(`~/.codex/models_cache.json`)를 읽어 OpenAI(ChatGPT) 모델 목록을 제공한다.
///
/// Codex CLI가 실행될 때마다 파일을 갱신하므로, 앱을 업데이트하지 않아도 새 모델이 목록에 나타난다.
/// 파일이 없거나 파싱에 실패하면 `fallbackModels`를 쓴다.
enum CodexModelCatalog {
    static let defaultModelSlug = "gpt-6-luna"

    /// 낮은 것부터 높은 순. 서버가 허용하지 않는 effort를 보내면 403(`reasoning_effort_not_allowed`)이 난다.
    static let effortOrder = ["none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra"]

    /// 과거 enum rawValue → 현재 slug.
    static let legacySlugAliases: [String: String] = [
        "gpt-5.6": "gpt-5.6-sol",
        "gpt-5.3-codex-spark": "gpt-5.4-mini",
        "gpt-5.2-codex": "gpt-5.2",
    ]

    /// 캐시가 없을 때 쓰는 목록. effort 정보가 없으므로 `reasoning` 필드는 생략된다.
    static let fallbackModels: [CodexModel] = [
        ("gpt-6.1-sol", "GPT-6.1-Sol"),
        ("gpt-6.1-terra", "GPT-6.1 Terra"),
        ("gpt-6-astra", "GPT-6-Astra"),
        ("gpt-6-sol", "GPT-6-Sol"),
        ("gpt-6-luna", "GPT-6-Luna"),
        ("gpt-5.6-sol", "GPT-5.6-Sol"),
        ("gpt-5.6-terra", "GPT-5.6-Terra"),
        ("gpt-5.6-luna", "GPT-5.6-Luna"),
    ].map { CodexModel(slug: $0.0, displayName: $0.1, description: "", supportsVision: true, supportedEfforts: []) }

    static var defaultCacheURL: URL {
        let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"].flatMap { $0.isEmpty ? nil : $0 }
        let base = codexHome.map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        return base.appendingPathComponent("models_cache.json")
    }

    /// 캐시 파일(수백 KB)을 읽지 않는 가벼운 표시 이름 — 렌더마다 호출되는 곳용.
    static func displayName(for slug: String) -> String {
        fallbackModels.first { $0.slug == slug }?.displayName ?? slug
    }

    static func normalizedSlug(_ slug: String) -> String {
        legacySlugAliases[slug] ?? slug
    }

    /// 캐시 파일을 읽는다. 없거나 깨졌으면 `fallbackModels`.
    static func load(from url: URL = defaultCacheURL) -> [CodexModel] {
        guard let data = try? Data(contentsOf: url), let models = decode(data) else {
            return fallbackModels
        }
        return models
    }

    /// 캐시 JSON을 디코드한다. 형식이 틀렸거나 표시할 모델이 하나도 없으면 nil.
    static func decode(_ data: Data) -> [CodexModel]? {
        guard let cache = try? JSONDecoder().decode(CacheFile.self, from: data) else { return nil }
        let models = cache.models
            .enumerated()
            .filter { _, entry in
                entry.slug?.isEmpty == false
                    && entry.visibility == "list"
                    && entry.supported_in_api != false
            }
            .sorted { lhs, rhs in
                let lp = lhs.element.priority ?? Int.max
                let rp = rhs.element.priority ?? Int.max
                return lp != rp ? lp < rp : lhs.offset < rhs.offset
            }
            .compactMap { _, entry -> CodexModel? in
                guard let slug = entry.slug else { return nil }
                let name = entry.display_name.flatMap { $0.isEmpty ? nil : $0 } ?? slug
                return CodexModel(
                    slug: slug,
                    displayName: name,
                    description: entry.description ?? "",
                    supportsVision: entry.input_modalities?.contains("image") ?? true,
                    supportedEfforts: entry.supported_reasoning_levels?.compactMap(\.effort) ?? []
                )
            }
        return models.isEmpty ? nil : models
    }

    static func lowestEffort(in efforts: [String]) -> String? {
        effortOrder.first { efforts.contains($0) }
    }

    // MARK: - Lenient decoding

    /// 알 수 없는 키는 무시되고, 모든 필드는 optional — Codex CLI 버전이 바뀌어도 디코드가 깨지지 않게.
    private struct CacheFile: Decodable {
        let models: [Entry]

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            var list = try c.nestedUnkeyedContainer(forKey: .models)
            var entries: [Entry] = []
            while !list.isAtEnd {
                // 깨진 항목 하나 때문에 전체 목록을 버리지 않는다.
                if let entry = try? list.decode(Entry.self) {
                    entries.append(entry)
                } else {
                    _ = try? list.decode(Skip.self)
                }
            }
            models = entries
        }

        private enum CodingKeys: String, CodingKey { case models }
        private struct Skip: Decodable {}
    }

    private struct Entry: Decodable {
        let slug: String?
        let display_name: String?
        let description: String?
        let visibility: String?
        let supported_in_api: Bool?
        let priority: Int?
        let input_modalities: [String]?
        let supported_reasoning_levels: [ReasoningLevel]?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            slug = try? c.decodeIfPresent(String.self, forKey: .slug)
            display_name = try? c.decodeIfPresent(String.self, forKey: .display_name)
            description = try? c.decodeIfPresent(String.self, forKey: .description)
            visibility = try? c.decodeIfPresent(String.self, forKey: .visibility)
            supported_in_api = try? c.decodeIfPresent(Bool.self, forKey: .supported_in_api)
            priority = try? c.decodeIfPresent(Int.self, forKey: .priority)
            input_modalities = try? c.decodeIfPresent([String].self, forKey: .input_modalities)
            supported_reasoning_levels = try? c.decodeIfPresent([ReasoningLevel].self, forKey: .supported_reasoning_levels)
        }

        private enum CodingKeys: String, CodingKey {
            case slug, display_name, description, visibility, supported_in_api, priority
            case input_modalities, supported_reasoning_levels
        }
    }

    private struct ReasoningLevel: Decodable {
        let effort: String?
    }
}
