import Foundation

public enum VoiceEdits {
    /// Treat quoted or reported commands as prose, rather than editing requests.
    public static func isLiteral(_ range: Range<String.Index>, in text: String) -> Bool {
        var closing: Character?
        var previous: Character?
        for character in text[..<range.lowerBound] {
            if let expected = closing {
                if character == expected { closing = nil }
            } else if character == "\"" { closing = "\"" }
            else if character == "“" { closing = "”" }
            else if character == "‘" { closing = "’" }
            else if character == "'" && previous?.isLetter != true { closing = "'" }
            previous = character
        }
        if closing != nil { return true }
        let prefix = String(text[..<range.lowerBound].suffix(100)).lowercased()
        let sentence = prefix.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).last ?? prefix
        if sentence.range(of: "(?i)(don't|don’t|do not|never|not to)\\s*$", options: .regularExpression) != nil { return true }
        return sentence.range(of: "\\b(said|says|say|phrase|command|example|called|quote)\\b", options: .regularExpression) != nil
    }
    public static func apply(_ original: String) -> String {
        let pattern = "(?i)\\b(?:please\\s+)?(?:(?:scratch|delete|remove)\\s+(?:the\\s+)?(?:last|previous)\\s+(?:line|sentence|word|paragraph)|scratch\\s+that|start\\s+over|clear\\s+(?:all\\s+of\\s+)?(?:that|everything))\\b[.,!?]?"
        let regex = try! NSRegularExpression(pattern: pattern)
        var result = "", cursor = original.startIndex
        for match in regex.matches(in: original, range: NSRange(original.startIndex..., in: original)) {
            guard let range = Range(match.range, in: original), !isLiteral(range, in: original) else { continue }
            result += original[cursor..<range.lowerBound]
            let command = original[range].lowercased()
            if command.contains("start over") || command.contains("clear") { result = "" }
            else if command.contains("word") {
                result = result.replacingOccurrences(of: "\\S+\\s*$", with: "", options: .regularExpression)
            } else if command.contains("paragraph") {
                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                result = trimmed.range(of: "\n\n", options: .backwards).map { String(trimmed[..<$0.lowerBound]) } ?? ""
            } else {
                var trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                while let last = trimmed.last, ".!?".contains(last) { trimmed.removeLast() }
                if let boundary = trimmed.lastIndex(where: { ".!?\n".contains($0) }) { result = String(trimmed[...boundary]) + " " }
                else { result = "" }
            }
            cursor = range.upperBound
        }
        result += original[cursor...]
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func formatting(_ input: String) -> (text: String, style: String?) {
        let pattern = "(?i)\\b(?:make|turn|put|format)\\s+(?:that|those|this|these|it|the above)(?:\\s+into|\\s+as)?\\s+(?:a\\s+)?(?:bullet points|bulleted list|numbered list|paragraphs?)[.,!?]?"
        let regex = try! NSRegularExpression(pattern: pattern)
        var output = input, style: String?
        let matches = regex.matches(in: input, range: NSRange(input.startIndex..., in: input))
        for match in matches {
            guard let range = Range(match.range, in: input), !isLiteral(range, in: input) else { continue }
            let command = input[range].lowercased()
            style = command.contains("numbered") ? "STEPS" : command.contains("paragraph") ? "PROSE" : "BULLETS"
        }
        for match in matches.reversed() {
            guard let range = Range(match.range, in: input), !isLiteral(range, in: input), let outputRange = Range(match.range, in: output) else { continue }
            output.removeSubrange(outputRange)
        }
        return (output.trimmingCharacters(in: .whitespacesAndNewlines), style)
    }

    public struct Correction: Codable {
        public let command: String
        public let target: String
        public let replacement: String
        public init(command: String, target: String, replacement: String) {
            self.command = command; self.target = target; self.replacement = replacement
        }
    }
    /// Apply one anchored correction. The model can only replace an earlier exact span.
    public static func correct(_ edit: Correction, in text: String) -> String? {
        var targetText = edit.target
        if edit.command.lowercased().contains("make that"),
           let qualifier = targetText.range(of: "(?i)\\s+(at|in|with|before|after)\\s+", options: .regularExpression) {
            targetText = String(targetText[..<qualifier.lowerBound])
        }
        guard !targetText.isEmpty, !edit.replacement.isEmpty, targetText.count <= 160,
              edit.replacement.count <= 160,
              targetText.split(whereSeparator: \.isWhitespace).count <= max(1, edit.replacement.split(whereSeparator: \.isWhitespace).count * 2),
              let command = text.range(of: edit.command), !isLiteral(command, in: text),
              edit.command.range(of: "(?i)^(?:actually[, ]+)?(?:make that|change |replace )", options: .regularExpression) != nil,
              edit.command.localizedCaseInsensitiveContains(edit.replacement),
              let target = text[..<command.lowerBound].range(of: targetText, options: .backwards) else { return nil }
        var result = text
        result.removeSubrange(command)
        result.replaceSubrange(target, with: edit.replacement)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
