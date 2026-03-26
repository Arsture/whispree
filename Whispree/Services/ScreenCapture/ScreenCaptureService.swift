import AppKit
import CoreGraphics

final class ScreenCaptureService {
    /// Screen Recording 권한 확인
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Screen Recording 권한 요청
    static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// previousApp의 메인 윈도우를 캡처하여 JPEG Data로 반환
    /// 권한 없거나 캡처 실패 시 nil 반환
    func captureWindow(of app: NSRunningApplication) -> Data? {
        guard ScreenCaptureService.hasScreenRecordingPermission() else { return nil }

        let pid = app.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // 해당 PID의 가장 큰 윈도우 (메인 윈도우) 찾기
        let appWindows = windowList.filter { dict in
            guard let ownerPID = dict[kCGWindowOwnerPID as String] as? Int32 else { return false }
            return ownerPID == pid
        }

        // 가장 큰 윈도우 선택 (면적 기준)
        guard let mainWindow = appWindows.max(by: { a, b in
            let boundsA = a[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let boundsB = b[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let areaA = (boundsA["Width"] ?? 0) * (boundsA["Height"] ?? 0)
            let areaB = (boundsB["Width"] ?? 0) * (boundsB["Height"] ?? 0)
            return areaA < areaB
        }),
            let windowID = mainWindow[kCGWindowNumber as String] as? CGWindowID
        else {
            return nil
        }

        // 윈도우 캡처
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .nominalResolution]
        ) else {
            return nil
        }

        // JPEG 변환 (0.7 품질 — 적절한 크기/품질 밸런스)
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
}
