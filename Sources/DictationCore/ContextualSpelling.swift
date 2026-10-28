import Foundation

public enum ContextualSpelling {
    public struct Edit: Codable, Sendable {
        public let heard: String
        public let term: String
        public init(heard: String, term: String) { self.heard = heard; self.term = term }
    }
    public static func decode(_ response: String) -> [Edit] {
        let json = response.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^```(?:json)?\\s*|\\s*```$", with: "", options: .regularExpression)
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Edit].self, from: data)) ?? []
    }
    public static func apply(_ edits: [Edit], to input: String, terms: [String]) -> String {
        var result = input
        for edit in edits.prefix(12) {
            guard terms.contains(edit.term), !edit.heard.isEmpty, edit.heard.count <= 80,
                  edit.heard.split(separator: " ").count <= 5,
                  edit.heard.allSatisfy({ $0.isLetter || $0.isWhitespace }),
                  similar(edit.heard, edit.term) else { continue }
            let pattern = "(?i)(?<![\\w./@-])" + NSRegularExpression.escapedPattern(for: edit.heard) + "(?![\\w./@-])"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            // Ambiguous repeated occurrences need separate review, not a global replacement.
            guard matches.count == 1, let range = Range(matches[0].range, in: result),
                  !VoiceEdits.isLiteral(range, in: result) else { continue }
            result.replaceSubrange(range, with: edit.term)
        }
        return result
    }
    public static func similar(_ lhs: String, _ rhs: String) -> Bool {
        func key(_ value: String) -> String {
            var words = value.lowercased().split(separator: " ").map(String.init)
            let letters = ["you": "u", "eye": "i", "cue": "q", "queue": "q", "kay": "k"]
            words = words.map { letters[$0] ?? $0 }
            var text = words.joined().filter { $0.isLetter }
            text = text.replacingOccurrences(of: "c(?=[eiy])", with: "s", options: .regularExpression)
            text = text.replacingOccurrences(of: "ph", with: "f")
            text = text.replacingOccurrences(of: "[aeiou]", with: "", options: .regularExpression)
            text = text.replacingOccurrences(of: "(.)\\1+", with: "$1", options: .regularExpression)
            return text
        }
        let a = key(lhs), b = key(rhs)
        return a.count >= 2 && a == b
    }
}
