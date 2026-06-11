import AppKit
import XCTest
@testable import Whispree

@MainActor
final class BrowserContextServiceTests: XCTestCase {
    private func snapshot() -> DictationJobSnapshot {
        DictationJobSnapshot(
            sttProviderType: .groq,
            llmProviderType: .openai,
            correctionMode: .standard,
            language: .korean
        )
    }

    func testQueueTargetContextCanStoreLatestTrackedChromeCaret() throws {
        let queue = DictationQueueState()
        let app = NSRunningApplication.current
        let original = ExternalContext.chromeTab(
            app: app,
            windowIndex: 1,
            tabIndex: 1,
            tabID: 123,
            tabURL: "https://chatgpt.com/",
            element: ElementInfo(
                selector: "#prompt-textarea",
                type: "ce",
                start: 42,
                end: 42,
                startPath: "0,1",
                endPath: "0,1",
                startNodeOffset: 0,
                endNodeOffset: 0
            )
        )
        let latest = ExternalContext.chromeTab(
            app: app,
            windowIndex: 1,
            tabIndex: 1,
            tabID: 123,
            tabURL: "https://chatgpt.com/",
            element: ElementInfo(
                selector: "#prompt-textarea",
                type: "ce",
                start: 58,
                end: 58,
                startPath: "2,0",
                endPath: "2,0",
                startNodeOffset: 1,
                endNodeOffset: 1
            )
        )

        let id = try XCTUnwrap(
            queue.enqueue(snapshot: snapshot(), audio: .memory([1]), targetContext: original)
        )
        queue.updateTargetContext(jobID: id, targetContext: latest)
        let job = try XCTUnwrap(queue.job(id: id))

        guard case let .chromeTab(_, _, _, _, _, element) = job.targetContext else {
            return XCTFail("Expected chromeTab context")
        }
        XCTAssertEqual(element?.start, 58)
        XCTAssertEqual(element?.end, 58)
        XCTAssertEqual(element?.startPath, "2,0")
        XCTAssertEqual(element?.endPath, "2,0")
        XCTAssertEqual(element?.startNodeOffset, 1)
        XCTAssertEqual(element?.endNodeOffset, 1)
    }
}
