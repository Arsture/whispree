import AppKit
import Combine
import Foundation

/// 녹음 중 연속 스크린샷 캡처 서비스
///
/// 동작 원리:
/// - 앱 포커스 변경 시: 이전 앱의 pending debounce를 즉시 flush(캡처) → 새 앱에 대해 debounce 시작
/// - 스크롤 이벤트 시: debounce 타이머 리셋 (스크롤 중에는 캡처하지 않음)
/// - debounce 타이머 만료 시: 현재 앱 화면 캡처
/// - 같은 앱에서도 스크롤 → 멈춤 반복 시 여러 장 캡처 가능
@MainActor
final class ContinuousScreenCaptureService {
    private let screenCaptureService = ScreenCaptureService()
    private var debounceTimer: Timer?
    private var scrollMonitor: Any?
    private var clickMonitor: Any?
    private var focusObserver: AnyCancellable?
    private var currentApp: NSRunningApplication?
    private var isActive = false

    private(set) var captures: [CapturedScreenshot] = []

    /// 새 스크린샷이 캡처될 때마다 호출
    var onCapture: ((CapturedScreenshot) -> Void)?

    /// debounce 간격 (초) — 포커스/스크롤 정지 후 이 시간이 지나면 캡처
    var debounceInterval: TimeInterval = 1.5

    /// 최대 캡처 수 (메모리 보호)
    var maxCaptures: Int = 20

    // MARK: - Lifecycle

    func startMonitoring() {
        guard !isActive else { return }
        isActive = true
        captures = []

        // 현재 포커스된 앱 기록
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            currentApp = frontmost
        }

        // 앱 포커스 변경 모니터링
        focusObserver = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] notification in
                guard let self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier != Bundle.main.bundleIdentifier
                else { return }
                Task { @MainActor [weak self] in
                    self?.handleFocusChange(to: app)
                }
            }

        // 스크롤 이벤트 모니터링 (전역)
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleScrollEvent()
            }
        }

        // 마우스 클릭 모니터링 (전역) — 같은 앱 내 윈도우 전환 감지
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleClickEvent()
            }
        }

        // 초기 앱에 대해 debounce 시작
        startDebounce()
    }

    /// 모니터링 중지. 캡처된 스크린샷 배열을 반환.
    func stopMonitoring() -> [CapturedScreenshot] {
        guard isActive else { return captures }
        isActive = false

        // pending debounce가 있으면 마지막 캡처 실행
        if debounceTimer != nil {
            captureCurrentApp()
        }

        cleanup()
        return captures
    }

    /// 모니터링 중지 (캡처 데이터 초기화 포함)
    func reset() {
        isActive = false
        cleanup()
        captures = []
    }

    // MARK: - Event Handlers

    private func handleFocusChange(to newApp: NSRunningApplication) {
        guard isActive else { return }

        // 이전 앱에 pending debounce가 있으면 즉시 캡처 (flush)
        if debounceTimer != nil, currentApp != nil {
            captureCurrentApp()
        }

        currentApp = newApp
        startDebounce()
    }

    private func handleScrollEvent() {
        guard isActive else { return }
        // 스크롤 중이면 debounce 리셋 — 멈출 때까지 대기
        startDebounce()
    }

    private func handleClickEvent() {
        guard isActive else { return }
        // 클릭 시 debounce 리셋 — 같은 앱 내 윈도우 전환 등 감지
        startDebounce()
    }

    // MARK: - Debounce

    private func startDebounce() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.captureCurrentApp()
            }
        }
    }

    // MARK: - Capture

    private func captureCurrentApp() {
        debounceTimer?.invalidate()
        debounceTimer = nil

        guard captures.count < maxCaptures else { return }

        guard let app = currentApp ?? NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }

        guard let imageData = screenCaptureService.captureWindow(of: app) else { return }

        let screenshot = CapturedScreenshot(
            id: UUID(),
            timestamp: Date(),
            appName: app.localizedName ?? "Unknown",
            appBundleIdentifier: app.bundleIdentifier,
            imageData: imageData
        )

        captures.append(screenshot)
        onCapture?(screenshot)
    }

    // MARK: - Cleanup

    private func cleanup() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        focusObserver = nil
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
