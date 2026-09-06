import Carbon.HIToolbox
import XCTest
@testable import SayType

final class KeyComboTests: XCTestCase {
    func testDefaultDisplayString() {
        XCTAssertEqual(KeyCombo.defaultDictation.displayString, "⌃⌥Space")
    }

    func testRoundTripsThroughJSON() throws {
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_D), carbonModifiers: UInt32(cmdKey | shiftKey))
        let data = try JSONEncoder().encode(combo)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)
        XCTAssertEqual(decoded, combo)
    }

    func testFunctionKeyNeedsNoModifier() {
        let combo = KeyCombo(keyCode: UInt32(kVK_F5), carbonModifiers: 0)
        XCTAssertTrue(combo.isUsableAsGlobalShortcut)
    }

    func testPlainLetterIsRejected() {
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_A), carbonModifiers: 0)
        XCTAssertFalse(combo.isUsableAsGlobalShortcut)
    }
}
