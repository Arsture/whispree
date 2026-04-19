import AppKit
import AVFoundation
import Carbon
import CoreGraphics
import Foundation

/// 앱 전역 권한 상태 싱글톤.
/// Microphone / Accessibility / ScreenRecording / Automation(per-bundleID)을 단일 ObservableObject로 관리.
/// 5초 간격 폴링으로 시스템 변경을 자동 반영.
@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    enum Status {
        case notDetermined, granted, denied, unavailable
    }

    enum PermissionKind: Hashable {
        case microphone
        case accessibility
        case screenRecording
        case automation(bundleID: String)
    }

    /// 사전 등록된 Automation 대상 번들 ID.
    static let knownAutomationTargets = [
        "com.apple.Music",
        "com.spotify.client",
        "com.google.Chrome",
        "com.googlecode.iterm2",
        "com.apple.systemevents",
    ]

    @Published private(set) var microphone: Status = .notDetermined
    @Published private(set) var accessibility: Status = .notDetermined
    @Published private(set) var screenRecording: Status = .notDetermined
    /// bundleID → 권한 상태
    @Published private(set) var automation: [String: Status] = [:]

    private var refreshTimer: Timer?

    private init() {
        refreshAll()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshAll() }
        }
    }

    // MARK: - Refresh (non-prompting)

    func refreshAll() {
        refresh(.microphone)
        refresh(.accessibility)
        refresh(.screenRecording)
        for bundleID in Self.knownAutomationTargets {
            refresh(.automation(bundleID: bundleID))
        }
    }

    func refresh(_ kind: PermissionKind) {
        switch kind {
        case .microphone:
            microphone = Self.currentMicrophoneStatus()
        case .accessibility:
            accessibility = AXIsProcessTrusted() ? .granted : .denied
        case .screenRecording:
            screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .denied
        case .automation(let bundleID):
            if !Self.isAppInstalled(bundleID: bundleID) {
                automation[bundleID] = .unavailable
            } else if !Self.isAppRunning(bundleID: bundleID) {
                // 앱 미실행 시 AE 호출은 -600 반환 → 기존 확정 상태를 덮어쓰지 않음
                if automation[bundleID] == nil {
                    automation[bundleID] = .notDetermined
                }
            } else {
                let fresh = Self.queryAutomationStatus(bundleID: bundleID, askIfNeeded: false)
                // notDetermined 결과는 jitter 방지를 위해 확정 상태(.granted/.denied)를 덮어쓰지 않음
                // (AEDetermineAPI와 실제 AppleScript 결과 간 불일치가 존재)
                let existing = automation[bundleID]
                if fresh == .notDetermined && (existing == .granted || existing == .denied) {
                    // 기존 확정 상태 유지
                } else {
                    automation[bundleID] = fresh
                }
            }
        }
    }

    // MARK: - Request (may prompt user)

    func requestMicrophone() async -> Status {
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVCaptureDevice.requestAccess(for: .audio) { cont.resume(returning: $0) }
        }
        microphone = granted ? .granted : .denied
        return microphone
    }

    /// Accessibility는 OS prompt를 띄운 후 즉시 반환 (사용자가 설정을 바꿔야 반영됨).
    func requestAccessibility() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
        AXIsProcessTrustedWithOptions(opts)
        refresh(.accessibility)
    }

    func requestScreenRecording() async -> Status {
        CGRequestScreenCaptureAccess()
        // 최대 2초 폴링 (OS 프롬프트 응답 대기)
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if CGPreflightScreenCaptureAccess() {
                screenRecording = .granted
                return .granted
            }
        }
        screenRecording = .denied
        return .denied
    }

    /// Automation TCC 프롬프트를 띄우고 사용자 응답을 기다려 반환.
    /// 실제 AppleScript 이벤트를 전송 — 미결정 시 macOS가 자동으로 TCC 프롬프트 표시.
    /// AEDeterminePermissionToAutomateTarget보다 신뢰성 높음.
    func requestAutomation(bundleID: String) async -> Status {
        guard Self.isAppInstalled(bundleID: bundleID) else {
            automation[bundleID] = .unavailable
            return .unavailable
        }

        // 앱이 실행 중이 아니면 먼저 launch — TCC 프롬프트는 대상 앱이 실행 중일 때만 표시됨
        if !Self.isAppRunning(bundleID: bundleID) {
            await Self.launchApp(bundleID: bundleID)
        }

        // 실제 AppleScript 이벤트 전송 — Background queue (NSAppleScript는 blocking)
        let status = await withCheckedContinuation { (cont: CheckedContinuation<Status, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let s = Self.probeViaAppleScript(bundleID: bundleID)
                cont.resume(returning: s)
            }
        }

        automation[bundleID] = status
        NSLog("[PermissionManager] requestAutomation \(bundleID) → \(status)")
        NSApp.activate(ignoringOtherApps: true)
        return status
    }

    /// NSAppleScript로 무해한 이벤트를 전송해 권한 상태 확인.
    /// - 성공(err=nil) → .granted
    /// - errorNumber -1743 → .denied (TCC 거부)
    /// - 기타 에러 → .notDetermined
    nonisolated private static func probeViaAppleScript(bundleID: String) -> Status {
        let source = "tell application id \"\(bundleID)\" to return name"
        guard let script = NSAppleScript(source: source) else { return .notDetermined }
        var err: NSDictionary?
        _ = script.executeAndReturnError(&err)
        if let err = err {
            let code = (err[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
            NSLog("[PermissionManager] AppleScript probe \(bundleID) err=\(code)")
            if code == -1743 { return .denied }
            return .notDetermined
        }
        return .granted
    }

    // MARK: - System Settings Deep Links

    func openSystemSettings(for kind: PermissionKind) {
        let fragment: String
        switch kind {
        case .microphone:     fragment = "Privacy_Microphone"
        case .accessibility:  fragment = "Privacy_Accessibility"
        case .screenRecording: fragment = "Privacy_ScreenCapture"
        case .automation:     fragment = "Privacy_Automation"
        }
        let urlStr = "x-apple.systempreferences:com.apple.preference.security?\(fragment)"
        if let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private Helpers

    nonisolated static func isAppInstalled(bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    nonisolated static func isAppRunning(bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
    }

    /// 대상 앱을 백그라운드로 launch하고 최대 3초 대기.
    @MainActor
    private static func launchApp(bundleID: String) async {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false
        config.addsToRecentItems = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        } catch {
            NSLog("[PermissionManager] launch failed for \(bundleID): \(error)")
        }
        // launch 직후 앱 초기화 대기 (TCC 프롬프트가 제대로 보이도록)
        try? await Task.sleep(nanoseconds: 800_000_000)
    }

    private static func currentMicrophoneStatus() -> Status {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:               return .granted
        case .denied, .restricted:      return .denied
        case .notDetermined:            return .notDetermined
        @unknown default:               return .notDetermined
        }
    }

    /// `AEDeterminePermissionToAutomateTarget` 래퍼.
    /// - `askIfNeeded: false` → 현재 상태만 조회 (non-blocking).
    /// - `askIfNeeded: true`  → TCC 프롬프트 발생 가능 (blocking, background queue 전용).
    ///
    /// 반환값 매핑 (AppleScript / Apple Events error codes):
    /// - `noErr` (0)         → .granted
    /// - `-1743`             → .denied          (errAEEventNotPermitted — TCC에서 명시적으로 거부됨)
    /// - `-1744`             → .notDetermined   (errAEEventWouldRequireUserConsent — 아직 결정 전, 물어봐야 함)
    /// - `-600`              → .notDetermined   (procNotFound — 대상 앱 미실행)
    /// - 기타                → .notDetermined
    nonisolated static func queryAutomationStatus(bundleID: String, askIfNeeded: Bool) -> Status {
        // typeApplicationBundleID = 'buin' (0x6275696e) — Carbon 브리지에서 타입 추론 실패 방지
        let kBundleIDType: DescType = 0x6275_696e
        let cStr = bundleID.utf8CString
        var targetDesc = AEDesc()
        var createErr: OSErr = 0
        cStr.withUnsafeBytes { ptr in
            createErr = AECreateDesc(kBundleIDType, ptr.baseAddress, ptr.count - 1, &targetDesc)
        }
        guard createErr == 0 else {
            NSLog("[PermissionManager] AECreateDesc failed for \(bundleID): \(createErr)")
            return .notDetermined
        }
        defer { AEDisposeDesc(&targetDesc) }

        let err = AEDeterminePermissionToAutomateTarget(&targetDesc, typeWildCard, typeWildCard, askIfNeeded)
        NSLog("[PermissionManager] queryAutomation bundleID=\(bundleID) askIfNeeded=\(askIfNeeded) err=\(err)")
        switch err {
        case noErr:              return .granted
        case OSStatus(-1743):    return .denied
        case OSStatus(-1744):    return .notDetermined
        case OSStatus(-600):     return .notDetermined
        default:                 return .notDetermined
        }
    }
}
