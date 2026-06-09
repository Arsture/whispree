import Foundation

/// Claude Code CLI(`claude -p`) LLM 모델 레지스트리.
///
/// `claude` CLI를 서브프로세스로 호출해 사용자의 **Claude 구독(Agent SDK 크레딧 풀)**으로 교정한다.
/// 별도 API 키/로그인 없이 머신에 설치된 Claude Code의 Keychain 로그인을 그대로 재사용한다.
///
/// - 모든 Claude 모델은 이미지 입력(`@경로` 첨부)을 지원하므로 `supportsVision == true`.
/// - rawValue는 CLI `--model`에 넘기는 **full model name**. alias(`haiku`/`sonnet`)는 무시되는 경우가
///   있어 full name으로 고정한다.
enum ClaudeCodeModel: String, CaseIterable, Codable {
    case haiku45 = "claude-haiku-4-5-20251001"
    case sonnet46 = "claude-sonnet-4-6"
    case opus48 = "claude-opus-4-8"

    var displayName: String {
        switch self {
            case .haiku45: "Claude Haiku 4.5"
            case .sonnet46: "Claude Sonnet 4.6"
            case .opus48: "Claude Opus 4.8"
        }
    }

    var description: String {
        switch self {
            case .haiku45: "가장 빠르고 크레딧 절약. 교정 용도 권장."
            case .sonnet46: "속도/품질 균형. 일반 교정에 적합."
            case .opus48: "최고 품질. 복잡한 교정·추론. (크레딧 소모 큼)"
        }
    }

    /// 모든 Claude 모델은 이미지(스크린샷) 입력을 지원한다.
    var supportsVision: Bool { true }

    /// 교정 품질 점수 (0-100, 주관적).
    var qualityScore: Int {
        switch self {
            case .opus48: 98
            case .sonnet46: 94
            case .haiku45: 86
        }
    }

    /// 예상 레이턴시 (ms). `claude -p` 콜드 스타트 + 추론 포함 대략치 — 프롬프트 캐시 웜 시 더 빠름.
    var estimatedLatencyMs: Int {
        switch self {
            case .haiku45: 2500
            case .sonnet46: 3500
            case .opus48: 5000
        }
    }
}
