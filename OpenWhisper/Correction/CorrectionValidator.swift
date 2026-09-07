import Foundation

enum CorrectionValidator {
    static let minimumWordRatio = 0.35
    static let maximumWordRatio = 2.5
    static let minimumOrderedOverlap = 0.35
    static let rejectedPrefixes = ["transcript:", "corrected:", "corrected transcript:", "output:", "result:", "here is", "here's", "sure,", "i'm sorry", "i am sorry", "as an ai"]

    static func accept(raw: String, corrected: String) -> String? {
        let candidate = normalized(corrected)
        guard !candidate.isEmpty else { return nil }

        let lowered = candidate.lowercased()
        guard !rejectedPrefixes.contains(where: { lowered.hasPrefix($0) }) else { return nil }

        let rawWords = words(in: raw)
        let candidateWords = words(in: candidate)
        guard !rawWords.isEmpty, !candidateWords.isEmpty else { return nil }

        let ratio = Double(candidateWords.count) / Double(rawWords.count)
        guard ratio >= minimumWordRatio, ratio <= maximumWordRatio else { return nil }

        let overlap = Double(longestCommonSubsequenceLength(rawWords, candidateWords)) / Double(rawWords.count)
        guard overlap >= minimumOrderedOverlap else { return nil }

        return candidate
    }

    static func longestCommonSubsequenceLength(_ first: [String], _ second: [String]) -> Int {
        guard !first.isEmpty, !second.isEmpty else { return 0 }
        var previousRow = [Int](repeating: 0, count: second.count + 1)
        for firstWord in first {
            var currentRow = [Int](repeating: 0, count: second.count + 1)
            for (column, secondWord) in second.enumerated() {
                currentRow[column + 1] = firstWord == secondWord
                    ? previousRow[column] + 1
                    : max(previousRow[column + 1], currentRow[column])
            }
            previousRow = currentRow
        }
        return previousRow[second.count]
    }

    static func normalized(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let wrappers: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("'", "'"), ("`", "`")]
        for (open, close) in wrappers where result.count >= 2 && result.first == open && result.last == close {
            result = String(result.dropFirst().dropLast())
        }
        result = result.replacingOccurrences(of: #"\s*\n+\s*"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
