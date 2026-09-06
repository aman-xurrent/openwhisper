import XCTest
@testable import SayType

final class WhisperModelTests: XCTestCase {
    func testCatalogHasNoDuplicateNames() {
        let names = WhisperModel.catalog.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testEveryModelBelongsToAFamilyByPrefix() {
        for model in WhisperModel.catalog {
            XCTAssertTrue(model.name.hasPrefix(model.family.rawValue), model.name)
        }
    }

    func testFamiliesCoverTheWholeCatalog() {
        let grouped = WhisperModelFamily.allCases.flatMap { WhisperModel.models(in: $0) }
        XCTAssertEqual(grouped.count, WhisperModel.catalog.count)
    }

    func testQuantizationIsReadFromTheSuffix() throws {
        XCTAssertEqual(try XCTUnwrap(WhisperModel.named("small.en-q5_1")).quantization, "q5_1")
        XCTAssertEqual(try XCTUnwrap(WhisperModel.named("large-v3-turbo-q8_0")).quantization, "q8_0")
        XCTAssertNil(try XCTUnwrap(WhisperModel.named("large-v3-turbo")).quantization)
    }

    func testEnglishOnlyDetection() throws {
        XCTAssertTrue(try XCTUnwrap(WhisperModel.named("medium.en-q5_0")).isEnglishOnly)
        XCTAssertFalse(try XCTUnwrap(WhisperModel.named("large-v2")).isEnglishOnly)
    }

    func testDownloadURLPointsAtHuggingFace() throws {
        let model = try XCTUnwrap(WhisperModel.named("base-q8_0"))
        XCTAssertEqual(
            model.downloadURL.absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q8_0.bin"
        )
    }
}
