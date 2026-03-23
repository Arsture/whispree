import Foundation

struct DomainWordSet: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var words: [String]
    var isEnabled: Bool

    static func generateDefault(domain: DomainCategory) -> DomainWordSet {
        switch domain {
        case .itDev:
            return DomainWordSet(id: UUID(), name: "IT/개발", words: [
                "API", "backend", "frontend", "React", "Swift", "Python",
                "GitHub", "PR", "merge", "deploy", "CI/CD", "Docker",
                "Kubernetes", "database", "query", "endpoint", "middleware",
                "refactor", "debug", "commit", "branch", "pipeline",
                "LLM", "GPT", "Claude", "Whisper", "CoreML", "MLX",
                "framework", "library", "package", "dependency",
                "authentication", "OAuth", "token", "JWT", "session",
                "server", "client", "request", "response", "streaming"
            ], isEnabled: true)
        case .statistics:
            return DomainWordSet(id: UUID(), name: "통계", words: [
                "T-distribution", "p-value", "regression", "hypothesis",
                "ANOVA", "chi-square", "correlation", "variance",
                "standard deviation", "confidence interval", "sample",
                "population", "mean", "median", "outlier", "bootstrap",
                "Bayesian", "posterior", "prior", "likelihood",
                "overfitting", "cross-validation", "feature", "gradient"
            ], isEnabled: true)
        case .custom:
            return DomainWordSet(id: UUID(), name: "사용자 정의", words: [], isEnabled: true)
        }
    }

    func buildPromptText() -> String {
        guard !words.isEmpty else { return "" }
        let chunks = words.chunked(into: 8)
        return chunks.map { chunk in
            "We discussed \(chunk.joined(separator: ", ")) in the meeting."
        }.joined(separator: " ")
    }
}

enum DomainCategory: String, CaseIterable, Codable {
    case itDev = "IT/개발"
    case statistics = "통계"
    case custom = "사용자 정의"
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
