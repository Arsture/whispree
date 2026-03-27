import AppKit
import Foundation

/// 연속 스크린샷 캡처 결과
struct CapturedScreenshot: Identifiable {
    let id: UUID
    let timestamp: Date
    let appName: String
    let appBundleIdentifier: String?
    let imageData: Data

    var image: NSImage? {
        NSImage(data: imageData)
    }
}
