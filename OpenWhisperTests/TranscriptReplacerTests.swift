import XCTest
@testable import OpenWhisper

final class TranscriptReplacerTests: XCTestCase {
    func testParsesEqualsAndArrowRules() {
        let rules = TranscriptReplacer.rules(from: "Vesper = whisper\nGod => guard\n  \njunkline\n")
        XCTAssertEqual(rules, [
            ReplacementRule(wrong: "Vesper", right: "whisper"),
            ReplacementRule(wrong: "God", right: "guard"),
        ])
    }

    func testReplacesWholeWordOnly() {
        let rules = [ReplacementRule(wrong: "cat", right: "dog")]
        XCTAssertEqual(TranscriptReplacer.apply(rules: rules, to: "the cat scattered"), "the dog scattered")
    }

    func testMatchesRegardlessOfCaseAndKeepsSampleCase() {
        let rules = [ReplacementRule(wrong: "vesper", right: "whisper")]
        XCTAssertEqual(TranscriptReplacer.apply(rules: rules, to: "keep only Vesper please"), "keep only Whisper please")
        XCTAssertEqual(TranscriptReplacer.apply(rules: rules, to: "keep only VESPER"), "keep only WHISPER")
        XCTAssertEqual(TranscriptReplacer.apply(rules: rules, to: "keep only vesper"), "keep only whisper")
    }

    func testAppliesEveryRuleAcrossTheSentence() {
        let rules = [
            ReplacementRule(wrong: "God", right: "guard"),
            ReplacementRule(wrong: "Vesper", right: "whisper"),
        ]
        let input = "God can miss it, so keep only Vesper. God is the check."
        XCTAssertEqual(
            TranscriptReplacer.apply(rules: rules, to: input),
            "Guard can miss it, so keep only Whisper. Guard is the check."
        )
    }

    func testHandlesRegexSpecialCharacters() {
        let rules = [ReplacementRule(wrong: "c++", right: "cpp")]
        XCTAssertEqual(TranscriptReplacer.apply(rules: rules, to: "I like c++"), "I like cpp")
    }

    func testEmptyRulesLeaveTextUnchanged() {
        XCTAssertEqual(TranscriptReplacer.apply(rules: [], to: "unchanged text"), "unchanged text")
    }
}
