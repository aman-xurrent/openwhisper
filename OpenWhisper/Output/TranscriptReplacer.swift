import Foundation

struct ReplacementRule: Equatable {
    let wrong: String
    let right: String
}

enum TranscriptReplacer {
    static let separators = ["=>", "="]

    static func rules(from text: String) -> [ReplacementRule] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            for separator in separators where trimmed.contains(separator) {
                let parts = trimmed.components(separatedBy: separator)
                guard parts.count == 2 else { continue }
                let wrong = parts[0].trimmingCharacters(in: .whitespaces)
                let right = parts[1].trimmingCharacters(in: .whitespaces)
                guard !wrong.isEmpty, !right.isEmpty else { continue }
                return ReplacementRule(wrong: wrong, right: right)
            }
            return nil
        }
    }

    static func apply(rules: [ReplacementRule], to text: String) -> String {
        var result = text
        for rule in rules {
            result = replace(wrong: rule.wrong, with: rule.right, in: result)
        }
        return result
    }

    private static func replace(wrong: String, with right: String, in text: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: wrong)
        let pattern = "(?<!\\w)\(escaped)(?!\\w)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let fullRange = NSRange(text.startIndex..., in: text)
        var output = text
        for match in regex.matches(in: text, options: [], range: fullRange).reversed() {
            guard let range = Range(match.range, in: output) else { continue }
            let matched = String(output[range])
            output.replaceSubrange(range, with: cased(right, like: matched))
        }
        return output
    }

    static func cased(_ replacement: String, like sample: String) -> String {
        if sample.count > 1, sample == sample.uppercased(), sample != sample.lowercased() {
            return replacement.uppercased()
        }
        if let first = sample.first, first.isUppercase {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }
}
