import Foundation
import SwiftUI

/// 모델 호환성 등급
enum CompatibilityGrade: String, Comparable {
    case runsGreat = "RUNS GREAT"
    case runsWell = "RUNS WELL"
    case decent = "DECENT"
    case tightFit = "TIGHT FIT"
    case barelyRuns = "BARELY RUNS"
    case tooHeavy = "TOO HEAVY"

    var color: Color {
        switch self {
        case .runsGreat, .runsWell: return .green
        case .decent: return .yellow
        case .tightFit: return .orange
        case .barelyRuns: return .red
        case .tooHeavy: return .gray
        }
    }

    var sortOrder: Int {
        switch self {
        case .runsGreat: return 6
        case .runsWell: return 5
        case .decent: return 4
        case .tightFit: return 3
        case .barelyRuns: return 2
        case .tooHeavy: return 1
        }
    }

    static func < (lhs: CompatibilityGrade, rhs: CompatibilityGrade) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

/// 모델 호환성 평가 결과
struct ModelCompatibilityResult {
    let modelSizeGB: Double
    let ramUsagePercent: Int       // 0-100 (전체 RAM 대비)
    let estimatedTokPerSec: Int   // 예상 토큰/초 (STT는 0)
    let score: Int                // 0-100
    let grade: CompatibilityGrade

    /// RAM 사용량 표시 색상
    var ramColor: Color {
        if ramUsagePercent <= 35 { return .green }
        if ramUsagePercent <= 55 { return .yellow }
        if ramUsagePercent <= 75 { return .orange }
        return .red
    }
}

/// 모델 호환성 계산기 — canirun.ai 참조 기반
///
/// 핵심 지표:
/// - ramRatio: 모델 크기 / 가용 메모리 (0~1+). Apple Silicon 통합 메모리 기준
/// - tok/s: 메모리 대역폭 / 모델 크기 * 효율계수
///
/// 참조 (canirun.ai, M2 Pro 16GB):
/// - 4.6GB 29% → RUNS WELL 73     - 7.7GB 48% → DECENT 57
/// - 5.1GB 32% → RUNS WELL 70     - 11.3GB 71% → BARELY RUNS 31
enum ModelCompatibility {
    private static let mlxEfficiency: Double = 0.55

    // 결과 메모이제이션. 디바이스는 런타임 불변이라 사실상 영구 캐시.
    // SwiftUI body에서 매 렌더마다 호출되던 비용 제거.
    private struct CacheKey: Hashable {
        let modelSizeBytes: Int64
        let otherModelSizeBytes: Int64
        let totalRAMGB: Int
        let memoryBandwidthGBs: Int
    }
    private static let cacheLock = NSLock()
    private static var cache: [CacheKey: ModelCompatibilityResult] = [:]

    static func evaluate(
        modelSizeBytes: Int64,
        otherModelSizeBytes: Int64 = 0,
        device: DeviceCapability = .current
    ) -> ModelCompatibilityResult {
        let key = CacheKey(
            modelSizeBytes: modelSizeBytes,
            otherModelSizeBytes: otherModelSizeBytes,
            totalRAMGB: device.totalRAMGB,
            memoryBandwidthGBs: device.memoryBandwidthGBs
        )
        cacheLock.lock()
        if let hit = cache[key] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()

        let result = compute(
            modelSizeBytes: modelSizeBytes,
            otherModelSizeBytes: otherModelSizeBytes,
            device: device
        )

        cacheLock.lock()
        cache[key] = result
        cacheLock.unlock()
        return result
    }

    private static func compute(
        modelSizeBytes: Int64,
        otherModelSizeBytes: Int64,
        device: DeviceCapability
    ) -> ModelCompatibilityResult {
        let modelSizeGB = Double(modelSizeBytes) / 1_000_000_000
        let otherSizeGB = Double(otherModelSizeBytes) / 1_000_000_000
        let totalUsedGB = modelSizeGB + otherSizeGB + DeviceCapability.osOverheadGB
        let totalRAMGB = Double(device.totalRAMGB)
        let usableRAMGB = totalRAMGB - DeviceCapability.osOverheadGB - otherSizeGB

        let ramUsage = min(100, Int((totalUsedGB / totalRAMGB) * 100))

        // 예상 tok/s
        let estimatedTokS: Int
        if modelSizeGB > 0 {
            let raw = Double(device.memoryBandwidthGBs) / modelSizeGB * mlxEfficiency
            estimatedTokS = Int(min(raw, 300))
        } else {
            estimatedTokS = 0
        }

        // --- 점수 계산: 가용 메모리 대비 모델 비율 + 속도 곡선 ---

        // 1) RAM fitness: 모델이 가용 메모리에 얼마나 여유있게 들어가는가
        let ramRatio = modelSizeGB / max(usableRAMGB, 1) // 0 ~ 1+
        let ramFitness: Double
        if ramRatio > 1.0 { ramFitness = 0 }          // 메모리 초과
        else if ramRatio > 0.85 { ramFitness = 15 }    // 거의 꽉 참
        else if ramRatio > 0.7 { ramFitness = 35 }     // 빠듯
        else if ramRatio > 0.5 { ramFitness = 55 }     // 보통
        else if ramRatio > 0.3 { ramFitness = 75 }     // 여유
        else { ramFitness = 95 }                        // 넉넉

        // 2) Speed fitness: 추론 속도가 실사용에 적합한가
        let speedFitness: Double
        let tps = Double(estimatedTokS)
        if tps >= 80 { speedFitness = 100 }       // 즉각 응답
        else if tps >= 40 { speedFitness = 85 }   // 빠름
        else if tps >= 20 { speedFitness = 65 }   // 적절
        else if tps >= 10 { speedFitness = 45 }   // 느리지만 사용 가능
        else if tps > 0 { speedFitness = 25 }     // 매우 느림
        else { speedFitness = 50 }                  // STT 등 tok/s 해당 없음

        // 3) 최종 점수: RAM(50%) + 속도(50%)
        let finalScore = Int(ramFitness * 0.5 + speedFitness * 0.5)

        let grade = gradeFromScore(finalScore)

        return ModelCompatibilityResult(
            modelSizeGB: modelSizeGB,
            ramUsagePercent: ramUsage,
            estimatedTokPerSec: estimatedTokS,
            score: finalScore,
            grade: grade
        )
    }

    /// 클라우드 모델 (RAM 사용 없음, 항상 RUNS GREAT)
    static func evaluateCloud() -> ModelCompatibilityResult {
        ModelCompatibilityResult(
            modelSizeGB: 0,
            ramUsagePercent: 0,
            estimatedTokPerSec: 0,
            score: 95,
            grade: .runsGreat
        )
    }

    private static func gradeFromScore(_ score: Int) -> CompatibilityGrade {
        if score >= 85 { return .runsGreat }
        if score >= 70 { return .runsWell }
        if score >= 55 { return .decent }
        if score >= 40 { return .tightFit }
        if score >= 20 { return .barelyRuns }
        return .tooHeavy
    }
}
