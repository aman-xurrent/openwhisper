import XCTest
@testable import OpenWhisper

final class TranscriptJoinerTests: XCTestCase {
    func testFirstTurnHasNoSeparator() {
        XCTAssertEqual(TranscriptJoiner.separator(afterPrevious: nil), "")
    }

    func testFollowingTurnGetsASpace() {
        XCTAssertEqual(TranscriptJoiner.separator(afterPrevious: "First sentence."), " ")
    }

    func testNoDoubleSpaceWhenPreviousEndedWithWhitespace() {
        XCTAssertEqual(TranscriptJoiner.separator(afterPrevious: "First sentence. "), "")
        XCTAssertEqual(TranscriptJoiner.separator(afterPrevious: "Line\n"), "")
    }
}
