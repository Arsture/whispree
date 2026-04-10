import XCTest
@testable import Whispree

final class AudioServiceTests: XCTestCase {
    func testTrimSilencePreservesQuietSpeechAboveTunedThreshold() {
        let audio = repeatedFrames(count: 12, amplitude: 0.005)

        let trimmed = AudioService.trimSilence(audio)

        XCTAssertEqual(trimmed.count, audio.count)
    }

    func testTrimSilencePreservesShortPauseBetweenSpeechSegments() {
        let audio =
            repeatedFrames(count: 5, amplitude: 0.006) +
            repeatedFrames(count: 6, amplitude: 0.0) +
            repeatedFrames(count: 5, amplitude: 0.006)

        let trimmed = AudioService.trimSilence(audio)

        XCTAssertEqual(trimmed.count, audio.count)
    }

    func testTrimSilenceRemovesOnlyLongSilenceRuns() {
        let audio =
            repeatedFrames(count: 5, amplitude: 0.006) +
            repeatedFrames(count: 15, amplitude: 0.0) +
            repeatedFrames(count: 5, amplitude: 0.006)

        let trimmed = AudioService.trimSilence(audio)

        XCTAssertLessThan(trimmed.count, audio.count)
        XCTAssertEqual(trimmed.count, repeatedFrames(count: 18, amplitude: 0.0).count)
    }

    func testTrimSilenceUsesCeilingWhenConvertingPaddingMsToFrames() {
        let audio =
            repeatedFrames(count: 3, amplitude: 0.006) +
            repeatedFrames(count: 12, amplitude: 0.0) +
            repeatedFrames(count: 3, amplitude: 0.006)

        let trimmed = AudioService.trimSilence(
            audio,
            frameMs: 100,
            paddingMs: 250,
            minSilenceMs: 900
        )

        XCTAssertEqual(trimmed.count, repeatedFrames(count: 14, amplitude: 0.0).count)
    }

    private func repeatedFrames(
        count: Int,
        amplitude: Float,
        sampleRate: Int = 16_000,
        frameMs: Int = 100
    ) -> [Float] {
        let frameSize = (sampleRate * frameMs) / 1_000
        return Array(repeating: amplitude, count: frameSize * count)
    }
}
