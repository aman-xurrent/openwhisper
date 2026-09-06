import AppKit
import XCTest
@testable import SayType

final class AppLaunchTests: XCTestCase {
    func testApplicationDelegateIsInstalled() {
        XCTAssertTrue(NSApplication.shared.delegate is AppDelegate, "NSApplicationMain ran without our delegate, so applicationDidFinishLaunching never fires")
    }
}
