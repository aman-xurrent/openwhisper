import XCTest
@testable import SayType

final class CorrectionEngineTests: XCTestCase {
    static let testModel = CorrectionModel.named("qwen2.5-3b-instruct-q4_k_m")!

    private func loadEngine() async throws -> CorrectionEngine {
        let store = await ModelStore()
        let modelURL = await store.fileURL(for: Self.testModel)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw XCTSkip("\(Self.testModel.fileName) missing. Run `make model` first.")
        }
        return try CorrectionEngine(modelURL: modelURL, modelName: Self.testModel.name, useGPU: true)
    }

    func testFixesCasingPunctuationAndVocabulary() async throws {
        let engine = try await loadEngine()
        let request = CorrectionRequest(
            transcript: "so i think we should ship the new keyboard on tuesday and then talk to sara about the i o s build",
            previousText: nil,
            vocabulary: ["Sarah", "iOS", "Xurrent"]
        )
        let output = try await engine.correct(request)
        let accepted = try XCTUnwrap(CorrectionValidator.accept(raw: request.transcript, corrected: output), "Rejected output: \(output)")
        XCTAssertTrue(accepted.contains("Tuesday"), accepted)
        XCTAssertTrue(accepted.contains("iOS"), accepted)
        XCTAssertTrue(accepted.hasSuffix("."), accepted)
    }

    func testFixesSoundAlikeWordFromContext() async throws {
        let engine = try await loadEngine()
        let request = CorrectionRequest(
            transcript: "you can switch the correction model off in the settings and keep only vesper for the transcription",
            previousText: nil,
            vocabulary: []
        )
        let output = try await engine.correct(request)
        let accepted = try XCTUnwrap(CorrectionValidator.accept(raw: request.transcript, corrected: output), "Rejected output: \(output)")
        XCTAssertTrue(accepted.lowercased().contains("whisper"), "Expected sound-alike fix, got: \(accepted)")
        XCTAssertFalse(accepted.lowercased().contains("vesper"), accepted)
    }

    func testDoesNotAnswerQuestionsInsideTranscript() async throws {
        let engine = try await loadEngine()
        let request = CorrectionRequest(
            transcript: "can you remind me what the capital of france is",
            previousText: nil,
            vocabulary: []
        )
        let output = try await engine.correct(request)
        let accepted = try XCTUnwrap(CorrectionValidator.accept(raw: request.transcript, corrected: output), "Rejected output: \(output)")
        XCTAssertFalse(accepted.lowercased().contains("paris"), accepted)
        XCTAssertTrue(accepted.lowercased().hasPrefix("can you remind me"), accepted)
    }
}
