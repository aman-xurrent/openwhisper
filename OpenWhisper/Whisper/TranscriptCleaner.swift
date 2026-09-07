import Foundation

enum TranscriptCleaner {
    static let knownNoise = [
        "[BLANK_AUDIO]",
        "[ Silence ]",
        "(silence)",
        "[silence]",
        "[inaudible]",
        "[ Inaudible ]",
        "(inaudible)",
        "[MUSIC]",
        "[Music]",
        "(music)",
        "♪",
    ]

    private static let upperCaseBracketPattern = #"\[[A-Z_ ]+\]"#
    private static let repeatedWhitespacePattern = #"\s{2,}"#

    static func clean(_ raw: String) -> String {
        var text = raw
        for noise in knownNoise {
            text = text.replacingOccurrences(of: noise, with: " ", options: .caseInsensitive)
        }
        text = text.replacingOccurrences(of: upperCaseBracketPattern, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: repeatedWhitespacePattern, with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
