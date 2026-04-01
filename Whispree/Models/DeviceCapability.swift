import Foundation
import Metal

/// macOS 하드웨어 감지 — Apple Silicon 칩, RAM, 대역폭, GPU 코어
struct DeviceCapability {
    let chipName: String
    let totalRAMGB: Int
    let memoryBandwidthGBs: Int
    let gpuCores: Int

    /// 싱글톤 — 앱 시작 시 한 번만 감지
    static let current: DeviceCapability = detect()

    /// OS + 기본 앱이 사용하는 메모리 오버헤드 (GB)
    static let osOverheadGB: Double = 4.0

    private static func detect() -> DeviceCapability {
        let totalRAM = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) // bytes → GB
        let chipName = getChipName()
        let bandwidth = lookupBandwidth(chip: chipName)
        let gpuCores = getGPUCores()

        return DeviceCapability(
            chipName: chipName,
            totalRAMGB: totalRAM,
            memoryBandwidthGBs: bandwidth,
            gpuCores: gpuCores
        )
    }

    private static func getChipName() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    private static func getGPUCores() -> Int {
        guard let device = MTLCreateSystemDefaultDevice() else { return 0 }
        // MTLDevice doesn't expose core count directly, estimate from chip name
        let name = device.name.lowercased()
        if name.contains("m4 max") { return 40 }
        if name.contains("m4 pro") { return 20 }
        if name.contains("m4") { return 10 }
        if name.contains("m3 max") { return 40 }
        if name.contains("m3 pro") { return 18 }
        if name.contains("m3") { return 10 }
        if name.contains("m2 ultra") { return 76 }
        if name.contains("m2 max") { return 38 }
        if name.contains("m2 pro") { return 19 }
        if name.contains("m2") { return 10 }
        if name.contains("m1 ultra") { return 64 }
        if name.contains("m1 max") { return 32 }
        if name.contains("m1 pro") { return 16 }
        if name.contains("m1") { return 8 }
        return 8
    }

    /// 칩 이름 → 메모리 대역폭 (GB/s) 룩업
    private static func lookupBandwidth(chip: String) -> Int {
        let lower = chip.lowercased()
        // M4 시리즈
        if lower.contains("m4 max") { return 546 }
        if lower.contains("m4 pro") { return 273 }
        if lower.contains("m4") { return 120 }
        // M3 시리즈
        if lower.contains("m3 max") { return 400 }
        if lower.contains("m3 pro") { return 150 }
        if lower.contains("m3") { return 100 }
        // M2 시리즈
        if lower.contains("m2 ultra") { return 800 }
        if lower.contains("m2 max") { return 400 }
        if lower.contains("m2 pro") { return 200 }
        if lower.contains("m2") { return 100 }
        // M1 시리즈
        if lower.contains("m1 ultra") { return 800 }
        if lower.contains("m1 max") { return 400 }
        if lower.contains("m1 pro") { return 200 }
        if lower.contains("m1") { return 68 }
        return 100 // 알 수 없는 칩 기본값
    }
}
