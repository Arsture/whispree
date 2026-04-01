import Foundation

/// 로컬 MLX 모델 레지스트리 — 지원 모델 목록 및 메타데이터
struct LocalModelSpec: Identifiable, Codable, Hashable {
    let id: String              // HuggingFace repo ID
    let displayName: String
    let description: String
    /// 실제 디스크/RAM 점유 크기 (bytes) — MoE는 전체 파라미터 기준
    let sizeBytes: Int64
    let capability: ModelCapability
    let minMemoryGB: Int
    /// 교정 품질 점수 (0-100)
    let qualityScore: Int

    enum ModelCapability: String, Codable {
        case text    // MLXLLM — 텍스트 전용
        case vision  // MLXVLM — 텍스트 + 이미지
    }

    /// 사람이 읽을 수 있는 크기 문자열
    var sizeDescription: String {
        let gb = Double(sizeBytes) / 1_000_000_000
        if gb < 1 {
            return String(format: "~%d MB", Int(gb * 1000))
        }
        return String(format: "~%.1f GB", gb)
    }

    /// 호환성 평가 (현재 디바이스 기준)
    func compatibility(otherModelSizeBytes: Int64 = 0) -> ModelCompatibilityResult {
        ModelCompatibility.evaluate(
            modelSizeBytes: sizeBytes,
            otherModelSizeBytes: otherModelSizeBytes
        )
    }

    /// ID로 모델 검색
    static func find(_ modelId: String) -> LocalModelSpec? {
        supported.first { $0.id == modelId }
    }

    // MARK: - 지원 모델 목록 (sizeBytes = 실제 디스크 크기 기준)

    static let supported: [LocalModelSpec] = [
        // Text-only (MLXLLM)
        LocalModelSpec(
            id: "mlx-community/Qwen3-1.7B-4bit",
            displayName: "Qwen3 1.7B (4-bit)",
            description: "경량 교정 — 빠른 속도, 적은 메모리",
            sizeBytes: 940_000_000,        // 실측 937 MB
            capability: .text,
            minMemoryGB: 8,
            qualityScore: 5
        ),
        LocalModelSpec(
            id: "mlx-community/Qwen3-4B-Instruct-2507-4bit",
            displayName: "Qwen3 4B (4-bit)",
            description: "균형 잡힌 교정 — 속도와 품질의 기본값",
            sizeBytes: 2_100_000_000,      // 실측 2.1 GB
            capability: .text,
            minMemoryGB: 8,
            qualityScore: 15
        ),
        LocalModelSpec(
            id: "mlx-community/Qwen3-8B-4bit",
            displayName: "Qwen3 8B (4-bit)",
            description: "고품질 한국어 교정 — 느리지만 정확",
            sizeBytes: 4_300_000_000,      // 실측 4.3 GB
            capability: .text,
            minMemoryGB: 16,
            qualityScore: 20
        ),
        LocalModelSpec(
            id: "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit",
            displayName: "Qwen3 Coder 30B MoE (4-bit)",
            description: "코딩 특화 MoE — 전체 30B RAM 필요, 활성 3B",
            sizeBytes: 16_000_000_000,     // 실측 16 GB (MoE 전체 파라미터)
            capability: .text,
            minMemoryGB: 32,
            qualityScore: 25
        ),
        LocalModelSpec(
            id: "mlx-community/GLM-4.7-Flash-4bit",
            displayName: "GLM-4.7 Flash (4-bit)",
            description: "중국어/한국어 강점 — 대형 모델",
            sizeBytes: 16_000_000_000,     // 실측 16 GB
            capability: .text,
            minMemoryGB: 32,
            qualityScore: 22
        ),
        // Vision (MLXVLM)
        LocalModelSpec(
            id: "mlx-community/Qwen3-VL-4B-Instruct-8bit",
            displayName: "Qwen3 VL 4B (8-bit)",
            description: "비전+텍스트 교정 — 스크린샷 컨텍스트 활용",
            sizeBytes: 4_800_000_000,      // 실측 4.8 GB
            capability: .vision,
            minMemoryGB: 16,
            qualityScore: 30
        ),
    ]

    /// 기본 모델 ID
    static let defaultModelId = "mlx-community/Qwen3-4B-Instruct-2507-4bit"
}
