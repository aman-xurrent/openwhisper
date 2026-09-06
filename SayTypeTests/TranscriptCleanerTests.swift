import XCTest
@testable import SayType

final class TranscriptCleanerTests: XCTestCase {
    func testTrimsSurroundingWhitespace() {
        XCTAssertEqual(TranscriptCleaner.clean("  hello world \n"), "hello world")
    }

    func testRemovesBlankAudioMarker() {
        XCTAssertEqual(TranscriptCleaner.clean(" [BLANK_AUDIO]"), "")
    }

    func testRemovesKnownNoiseInsideText() {
        XCTAssertEqual(TranscriptCleaner.clean("Send it (silence) tomorrow"), "Send it tomorrow")
    }

    func testKeepsSpokenParentheses() {
        XCTAssertEqual(TranscriptCleaner.clean("Call me (after lunch) please"), "Call me (after lunch) please")
    }

    func testCollapsesRepeatedSpaces() {
        XCTAssertEqual(TranscriptCleaner.clean("one   two  three"), "one two three")
    }
}
