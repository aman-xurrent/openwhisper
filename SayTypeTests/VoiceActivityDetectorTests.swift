import XCTest
@testable import SayType

final class VoiceActivityDetectorTests: XCTestCase {
    func testDetectsSpeechInJFKSample() async throws {
        let store = await ModelStore()
        let modelURL = await store.fileURL(for: VADModel.silero)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("Silero model missing. Run `make model` first.")
        }
        let detector = try VoiceActivityDetector(modelURL: modelURL)
        let sampleURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "jfk", withExtension: "wav"))
        let samples = try AudioFixtures.loadMonoSixteenKilohertz(from: sampleURL)

        var probabilities: [Float] = []
        var consumed = 0
        for start in stride(from: 0, to: samples.count, by: 1_600) {
            let end = min(start + 1_600, samples.count)
            let result = detector.process(Array(samples[start..<end]))
            probabilities.append(contentsOf: result.probabilities)
            consumed += result.consumedSamples.count
            XCTAssertEqual(result.consumedSamples.count / VoiceActivityDetector.windowSize, result.probabilities.count)
        }

        XCTAssertEqual(consumed, samples.count / VoiceActivityDetector.windowSize * VoiceActivityDetector.windowSize)
        XCTAssertTrue(probabilities.allSatisfy { $0 >= 0 && $0 <= 1 })
        let speechWindows = probabilities.filter { $0 >= 0.5 }.count
        XCTAssertGreaterThan(Double(speechWindows) / Double(probabilities.count), 0.4, "JFK clip should be mostly speech")
    }

    func testSilenceHasLowProbability() async throws {
        let store = await ModelStore()
        let modelURL = await store.fileURL(for: VADModel.silero)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("Silero model missing. Run `make model` first.")
        }
        let detector = try VoiceActivityDetector(modelURL: modelURL)
        let result = detector.process([Float](repeating: 0, count: 16_000))
        XCTAssertEqual(result.probabilities.count, 16_000 / VoiceActivityDetector.windowSize)
        XCTAssertTrue(result.probabilities.allSatisfy { $0 < 0.5 })
    }
}
