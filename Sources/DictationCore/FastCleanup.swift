import Foundation

public enum FastCleanup {
    public static func hasVocabularyCandidate(_ text: String, terms: [String]) -> Bool {
        !candidateTerms(text, terms: terms).isEmpty
    }
    /// Compute each vocabulary key once rather than for every word window.
    public static func candidateTerms(_ text: String, terms: [String]) -> [String] {
        let terms = Array(terms.prefix(60))
        guard !terms.isEmpty else { return [] }
        let indexed = Dictionary(grouping: terms, by: ContextualSpelling.phoneticKey)
        let words = text.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }
        var candidates = Set<String>()
        for start in words.indices {
            for length in 1...min(5, words.count-start) {
                let phrase = words[start..<start+length].joined(separator: " ")
                let key = ContextualSpelling.phoneticKey(phrase)
                guard key.count >= 2, let matches = indexed[key] else { continue }
                for term in matches where term.caseInsensitiveCompare(phrase) != .orderedSame { candidates.insert(term) }
            }
        }
        return terms.filter { candidates.contains($0) }
    }
}
