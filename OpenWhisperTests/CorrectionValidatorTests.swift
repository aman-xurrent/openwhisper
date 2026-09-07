import XCTest
@testable import OpenWhisper

final class CorrectionValidatorTests: XCTestCase {
    func testAcceptsPunctuationAndCasingFix() {
        let raw = "so we ship the keyboard on tuesday and talk to sarah"
        let corrected = "So we ship the keyboard on Tuesday and talk to Sarah."
        XCTAssertEqual(CorrectionValidator.accept(raw: raw, corrected: corrected), corrected)
    }

    func testStripsWrappingQuotes() {
        XCTAssertEqual(CorrectionValidator.accept(raw: "hello there", corrected: "\"Hello there.\""), "Hello there.")
    }

    func testAcceptsFillerRemoval() {
        let raw = "um so I think uh we should go"
        let corrected = "So I think we should go."
        XCTAssertEqual(CorrectionValidator.accept(raw: raw, corrected: corrected), corrected)
    }

    func testAcceptsAReasonableAddition() {
        let raw = "if account id missing return error"
        let corrected = "If the account ID is missing, return an error."
        XCTAssertEqual(CorrectionValidator.accept(raw: raw, corrected: corrected), corrected)
    }

    func testAcceptsSoundAlikeSubstitution() {
        let raw = "keep only vesper for now"
        let corrected = "Keep only Whisper for now."
        XCTAssertEqual(CorrectionValidator.accept(raw: raw, corrected: corrected), corrected)
    }

    func testRejectsEmptyOutput() {
        XCTAssertNil(CorrectionValidator.accept(raw: "hello there", corrected: "   \n"))
    }

    func testRejectsLabelledOutput() {
        XCTAssertNil(CorrectionValidator.accept(raw: "hello there", corrected: "Corrected: Hello there."))
    }

    func testRejectsGrossExpansion() {
        let raw = "send it"
        let expanded = "Please send the document to the whole team as soon as you possibly can today, thank you."
        XCTAssertNil(CorrectionValidator.accept(raw: raw, corrected: expanded))
    }

    func testRejectsNearTotalRewrite() {
        let raw = "the cat sat on the mat by the door"
        XCTAssertNil(CorrectionValidator.accept(raw: raw, corrected: "Quantum physics is genuinely fascinating."))
    }

    func testCollapsesNewlinesToOneLine() {
        XCTAssertEqual(CorrectionValidator.normalized("First part.\n\nSecond part."), "First part. Second part.")
    }
}
