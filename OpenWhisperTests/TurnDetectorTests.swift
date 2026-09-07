import XCTest
@testable import OpenWhisper

final class TurnDetectorTests: XCTestCase {
    private let configuration = TurnDetectorConfiguration(
        sampleRate: 16_000,
        windowSize: 512,
        speechThreshold: 0.5,
        minimumSpeechSeconds: 0.25,
        pauseSeconds: 0.8,
        maximumTurnSeconds: 28,
        paddingSeconds: 0.3
    )

    private var windowSamples: Int { configuration.windowSize }

    private func feed(_ detector: TurnDetector, speech: Bool, windows: Int, amplitude: Float = 0.1) -> [TurnDetector.Event] {
        let samples = [Float](repeating: speech ? amplitude : 0, count: windows * windowSamples)
        let probabilities = [Float](repeating: speech ? 0.9 : 0.05, count: windows)
        return detector.process(samples: samples, probabilities: probabilities)
    }

    private func windows(forSeconds seconds: Double) -> Int {
        Int((seconds * Double(configuration.sampleRate)).rounded(.up)) / windowSamples + 1
    }

    func testNoEventsForSilence() {
        let detector = TurnDetector(configuration: configuration)
        XCTAssertEqual(feed(detector, speech: false, windows: 100), [])
        XCTAssertFalse(detector.isInSpeech)
    }

    func testSpeechStartsAfterMinimumDuration() {
        let detector = TurnDetector(configuration: configuration)
        XCTAssertEqual(feed(detector, speech: true, windows: 3), [])
        let events = feed(detector, speech: true, windows: windows(forSeconds: 0.25))
        XCTAssertEqual(events, [.speechStarted])
        XCTAssertTrue(detector.isInSpeech)
    }

    func testShortBlipDoesNotStartSpeech() {
        let detector = TurnDetector(configuration: configuration)
        XCTAssertEqual(feed(detector, speech: true, windows: 2), [])
        XCTAssertEqual(feed(detector, speech: false, windows: 2), [])
        XCTAssertEqual(feed(detector, speech: true, windows: 2), [])
        XCTAssertFalse(detector.isInSpeech)
    }

    func testTurnEndsAfterPauseAndKeepsPaddingOnly() throws {
        let detector = TurnDetector(configuration: configuration)
        _ = feed(detector, speech: false, windows: 40)
        _ = feed(detector, speech: true, windows: windows(forSeconds: 2))
        let events = feed(detector, speech: false, windows: windows(forSeconds: 0.8))
        let turn = try XCTUnwrap(events.compactMap { event -> [Float]? in
            if case .turnEnded(let samples) = event { return samples }
            return nil
        }.first)

        let leadingSilence = turn.prefix { $0 == 0 }.count
        let trailingSilence = turn.reversed().prefix { $0 == 0 }.count
        XCTAssertLessThanOrEqual(leadingSilence, configuration.paddingSamples + windowSamples)
        XCTAssertLessThanOrEqual(trailingSilence, configuration.paddingSamples + windowSamples)
        XCTAssertGreaterThan(turn.filter { $0 != 0 }.count, configuration.sampleRate)
        XCTAssertFalse(detector.isInSpeech)
    }

    func testBriefPauseInsideSentenceDoesNotEndTurn() {
        let detector = TurnDetector(configuration: configuration)
        _ = feed(detector, speech: true, windows: windows(forSeconds: 1))
        XCTAssertEqual(feed(detector, speech: false, windows: windows(forSeconds: 0.3)), [])
        XCTAssertEqual(feed(detector, speech: true, windows: windows(forSeconds: 1)), [])
        XCTAssertTrue(detector.isInSpeech)
    }

    func testLongSpeechIsCutAtMaximumDuration() {
        let detector = TurnDetector(configuration: configuration)
        let events = feed(detector, speech: true, windows: windows(forSeconds: 29))
        let turns = events.filter { if case .turnEnded = $0 { return true } else { return false } }
        XCTAssertEqual(turns.count, 1)
        XCTAssertTrue(detector.isInSpeech)
    }

    func testFlushReturnsInProgressSpeech() {
        let detector = TurnDetector(configuration: configuration)
        _ = feed(detector, speech: true, windows: windows(forSeconds: 1))
        let flushed = detector.flush()
        XCTAssertNotNil(flushed)
        XCTAssertGreaterThan(flushed?.count ?? 0, configuration.sampleRate / 2)
        XCTAssertFalse(detector.isInSpeech)
    }

    func testFlushDuringSilenceReturnsNothing() {
        let detector = TurnDetector(configuration: configuration)
        _ = feed(detector, speech: false, windows: 50)
        XCTAssertNil(detector.flush())
    }
}
