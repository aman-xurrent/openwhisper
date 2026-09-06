import XCTest
@testable import SayType

final class WhisperEngineTests: XCTestCase {
    static let testModel = WhisperModel.named("tiny.en")!

    func testTranscribesJFKSample() async throws {
        let store = await ModelStore()
        let modelURL = await store.fileURL(for: Self.testModel)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("tiny.en model missing. Run `make model` first.")
        }
        let engine = try WhisperEngine(modelURL: modelURL, modelName: Self.testModel.name, useGPU: true)

        let sampleURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "jfk", withExtension: "wav"))
        let samples = try AudioFixtures.loadMonoSixteenKilohertz(from: sampleURL)

        let text = TranscriptCleaner.clean(try await engine.transcribe(samples, language: "en"))

        XCTAssertTrue(text.lowercased().contains("ask not what your country can do for you"), "Unexpected transcript: \(text)")
    }

    func testEnglishOnlyModelIsNotMultilingual() async throws {
        let store = await ModelStore()
        let modelURL = await store.fileURL(for: Self.testModel)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("tiny.en model missing. Run `make model` first.")
        }
        let engine = try WhisperEngine(modelURL: modelURL, modelName: Self.testModel.name, useGPU: false)
        XCTAssertFalse(engine.isMultilingual)
    }
}
