import Foundation

public enum FastCleanup {
    public static func hasVocabularyCandidate(_ text: String, terms: [String]) -> Bool {
        let words = text.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
        guard !words.isEmpty else { return false }
        for start in words.indices {
            for length in 1...min(5, words.count-start) {
                let phrase = words[start..<start+length].joined(separator: " ")
                if terms.prefix(60).contains(where: { $0.caseInsensitiveCompare(phrase) != .orderedSame && ContextualSpelling.similar(phrase, $0) }) { return true }
            }
        }
        return false
    }
}
