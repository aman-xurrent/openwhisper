import XCTest
@testable import SayType

final class AudioAnalysisTests: XCTestCase {
    func testSilenceHasNoSpeech() {
        let silence = [Float](repeating: 0, count: 16_000)
        XCTAssertFalse(AudioAnalysis.containsSpeech(silence))
    }

    func testToneHasSpeech() {
        let tone = (0..<16_000).map { Float(sin(Double($0) * 0.05)) * 0.1 }
        XCTAssertTrue(AudioAnalysis.containsSpeech(tone))
    }

    func testShortBurstInsideSilenceCounts() {
        var samples = [Float](repeating: 0, count: 48_000)
        for index in 20_000..<22_000 {
            samples[index] = 0.2
        }
        XCTAssertTrue(AudioAnalysis.containsSpeech(samples))
    }

    func testRootMeanSquareOfEmptyIsZero() {
        XCTAssertEqual(AudioAnalysis.rootMeanSquare([]), 0)
    }
}
