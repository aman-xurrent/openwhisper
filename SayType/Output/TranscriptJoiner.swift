import Foundation

enum TranscriptJoiner {
    static func separator(afterPrevious previous: String?) -> String {
        guard let previous, let last = previous.last else { return "" }
        return last.isWhitespace || last.isNewline ? "" : " "
    }
}
