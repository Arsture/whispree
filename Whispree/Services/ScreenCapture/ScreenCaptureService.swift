import AppKit
import CoreGraphics

final class ScreenCaptureService {
    /// Screen Recording 권한 확인
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Screen Recording 권한 요청
    static func requestScreenRecordingPermission() {
        Task { @MainActor in
            await PermissionManager.shared.requestScreenRecording()
        }
    }

    /// 앱의 최상위(frontmost) 윈도우를 캡처하여 JPEG Data로 반환
    /// CGWindowListCopyWindowInfo는 front-to-back 순서로 반환하므로
    /// 첫 번째 매칭 윈도우가 가장 앞에 있는 윈도우 (활성 채팅방 등)
    /// 권한 없거나 캡처 실패 시 nil 반환
    func captureWindow(of app: NSRunningApplication) -> Data? {
        guard ScreenCaptureService.hasScreenRecordingPermission() else { return nil }

        let pid = app.processIdentifier
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // 해당 PID의 윈도우 중 일반 레이어(0)이고 최소 크기 이상인 것만 필터
        // CGWindowListCopyWindowInfo는 front-to-back 순서로 반환 → first = 최상위 윈도우
        let minArea: CGFloat = 100 * 100  // 너무 작은 팝오버/메뉴 제외
        guard let frontWindow = windowList.first(where: { dict in
            guard let ownerPID = dict[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let layer = dict[kCGWindowLayer as String] as? Int,
                  layer == 0  // 일반 윈도우 레이어만 (상태바/메뉴 제외)
            else { return false }
            let bounds = dict[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let area = (bounds["Width"] ?? 0) * (bounds["Height"] ?? 0)
            return area >= minArea
        }),
            let windowID = frontWindow[kCGWindowNumber as String] as? CGWindowID
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
