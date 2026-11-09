import AppKit
import ApplicationServices

/// Raw post-paste observation of the target text field via the Accessibility API.
///
/// Flow: `capture(app:)` right before paste → `start()` after paste → polls every 1s up
/// to 60s, emitting value-change events, and ends on timeout / focus change / app switch /
/// field emptied / next delivery. Runs independently of FIFO delivery.
@MainActor
final class EditObservation {
    enum EndReason: String {
        case timeout, focusChange = "focus_change", fieldEmptied = "field_emptied"
        case appSwitch = "app_switch", nextDelivery = "next_delivery", error
    }

    enum Status: String {
        case ok, unsupported, secureFieldSkipped = "secure_field_skipped", error
    }

    struct Snapshot {
        let value: String
        let selection: CFRange?

        var selectionText: String? {
            selection.map { "\($0.location),\($0.length)" }
        }
    }

    /// Sink for persisted rows; implemented by `TrainingDataRecorder`.
    struct Sink {
        let begin: (_ id: String, _ status: Status, _ role: String?, _ before: Snapshot?, _ startedAt: Date) -> Void
        let after: (_ id: String, _ snapshot: Snapshot?) -> Void
        let event: (_ id: String, _ seq: Int, _ tMs: Int, _ kind: String, _ value: Snapshot?) -> Void
        let end: (_ id: String, _ finalValue: String?, _ reason: EndReason, _ endedAt: Date) -> Void
    }

    static let pollInterval: UInt64 = 1_000_000_000
    static let maxDuration: TimeInterval = 60
    static let afterPasteDelay: UInt64 = 300_000_000

    let id = UUID().uuidString
    let sessionID: String
    private let sink: Sink
    private let pid: pid_t
    private let appElement: AXUIElement
    private let element: AXUIElement?
    private let status: Status
    private var pasteTime = Date()
    private var seq = 0
    private var lastValue: String?
    private var lastNonEmpty: String?
    private var task: Task<Void, Never>?
    private(set) var isFinished = false
    /// True while the user is in another app/field. Observation pauses instead of ending so a
    /// quick glance elsewhere (Cmd+Tab, Spotlight, another window) doesn't drop the edits.
    private var isPaused = false
    var onFinish: (() -> Void)?

    /// Reads the focused element of `app` and its pre-paste value. Records the observation row.
    init(sessionID: String, app: NSRunningApplication, sink: Sink) {
        self.sessionID = sessionID
        self.sink = sink
        pid = app.processIdentifier
        appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.25)

        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused)
        let element = focusedResult == .success ? (focused as! AXUIElement) : nil
        self.element = element
        if let element { AXUIElementSetMessagingTimeout(element, 0.25) }

        let role = element.flatMap { Self.string($0, kAXRoleAttribute) }
        let subrole = element.flatMap { Self.string($0, kAXSubroleAttribute) }
        var before: Snapshot?
        if element == nil {
            status = .unsupported
        } else if role == "AXSecureTextField" || subrole == "AXSecureTextField" {
            status = .secureFieldSkipped
        } else if let snapshot = element.flatMap(Self.read) {
            status = .ok
            before = snapshot
            lastValue = snapshot.value
            if !snapshot.value.isEmpty { lastNonEmpty = snapshot.value }
        } else {
            status = .unsupported
        }
        sink.begin(id, status, role, before, Date())
    }

    /// Call right after the paste keystroke was posted.
    func start() {
        pasteTime = Date()
        guard status == .ok, element != nil else {
            // unsupported / secure field: the status column already says why; nothing to watch.
            isFinished = true
            onFinish?()
            return
        }
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.afterPasteDelay)
            guard let self, !Task.isCancelled, !isFinished else { return }
            let after = element.flatMap(Self.read)
            sink.after(id, after)
            if let after { observe(after) }
            while !Task.isCancelled, !isFinished {
                try? await Task.sleep(nanoseconds: Self.pollInterval)
                guard !Task.isCancelled, !isFinished else { return }
                tick()
            }
        }
    }

    /// Control-key marker from the event tap (enter / cmd_enter / esc / cmd_z).
    func marker(_ kind: String) {
        guard !isFinished, !isPaused,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        else { return }
        emit(kind, value: nil)
    }

    func stop(_ reason: EndReason) {
        finish(reason)
    }

    private func tick() {
        if Date().timeIntervalSince(pasteTime) >= Self.maxDuration {
            finish(.timeout)
            return
        }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != pid {
            pause("app_switch")
            return
        }
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard result == .success, let element, CFEqual(focused, element) else {
            pause("focus_change")
            return
        }
        if isPaused {
            isPaused = false
            emit("focus_back", value: nil)
        }
        guard let snapshot = Self.read(element) else {
            finish(.error)
            return
        }
        observe(snapshot)
    }

    private func pause(_ kind: String) {
        guard !isPaused else { return }
        isPaused = true
        emit(kind, value: nil)
    }

    private func observe(_ snapshot: Snapshot) {
        guard snapshot.value != lastValue else { return }
        lastValue = snapshot.value
        if snapshot.value.isEmpty {
            emit("field_emptied", value: nil)
            finish(.fieldEmptied)
            return
        }
        lastNonEmpty = snapshot.value
        emit("value", value: snapshot)
    }

    private func emit(_ kind: String, value: Snapshot?) {
        seq += 1
        let tMs = Int(Date().timeIntervalSince(pasteTime) * 1000)
        sink.event(id, seq, tMs, kind, value)
    }

    private func finish(_ reason: EndReason) {
        guard !isFinished else { return }
        isFinished = true
        task?.cancel()
        task = nil
        sink.end(id, lastNonEmpty, reason, Date())
        onFinish?()
    }

    // MARK: - AX helpers

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private static func read(_ element: AXUIElement) -> Snapshot? {
        guard let value = string(element, kAXValueAttribute) else { return nil }
        var rangeRef: CFTypeRef?
        var selection: CFRange?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
           let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID()
        {
            var range = CFRange()
            if AXValueGetValue(rangeRef as! AXValue, .cfRange, &range) { selection = range }
        }
        return Snapshot(value: value, selection: selection)
    }
}
