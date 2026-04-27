import Foundation

enum OpenAIModel: String, CaseIterable, Codable {
    case gpt55 = "gpt-5.5"
    case gpt54 = "gpt-5.4"
    case gpt54mini = "gpt-5.4-mini"
    case gpt53codex = "gpt-5.3-codex"
    case gpt52 = "gpt-5.2"

    static let rawAliasMap: [String: String] = [
        "gpt-5.3-codex-spark": "gpt-5.4-mini",
        "gpt-5.2-codex": "gpt-5.2",
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        let normalized = Self.rawAliasMap[rawValue] ?? rawValue
        guard let model = Self(rawValue: normalized) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown OpenAI model: \(rawValue)"
            )
        }
        self = model
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
            case .gpt55: "GPT-5.5 (Latest)"
            case .gpt54: "GPT-5.4"
            case .gpt54mini: "GPT-5.4 Mini (Fast)"
            case .gpt53codex: "GPT-5.3 Codex"
            case .gpt52: "GPT-5.2"
        }
    }

    var description: String {
        switch self {
            case .gpt55: "최신 최고 품질. 긴 컨텍스트와 복잡한 교정에 적합"
            case .gpt54: "고품질. 코딩 + 추론 통합 모델"
            case .gpt54mini: "빠른 응답. 짧은 교정에 적합"
            case .gpt53codex: "코딩 특화. 기술 용어 교정에 강함"
            case .gpt52: "이전 세대. 호환성 우선"
        }
    }

    /// 교정 품질 점수 (0-100)
    var qualityScore: Int {
        switch self {
            case .gpt55: 100
            case .gpt54: 94
            case .gpt53codex: 82
            case .gpt54mini: 78
            case .gpt52: 75
        }
    }

    /// 예상 레이턴시 (ms)
    var estimatedLatencyMs: Int {
        switch self {
            case .gpt54mini: 600
            case .gpt53codex: 800
            case .gpt52: 900
            case .gpt55: 1100
            case .gpt54: 1200
        }
    }
}
