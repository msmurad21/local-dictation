import Foundation

public enum RecordingMode: String, Codable, CaseIterable {
    case pushToTalk, toggle
    public var title: String { self == .pushToTalk ? "Push to talk" : "Toggle" }
}

public enum ShortcutAction: Equatable { case beginHold, endHold, toggle, finish }
public struct ShortcutRouter {
    private var down = false
    private var chord = false
    public init() {}
    public mutating func press(mode: RecordingMode, finishingHandsFree: Bool = false) -> ShortcutAction? {
        guard !down else { return nil }
        down = true; chord = finishingHandsFree
        // Consume release and any Space in this key cycle after finishing.
        if finishingHandsFree { return .finish }
        return mode == .pushToTalk ? .beginHold : nil
    }
    public mutating func space() -> ShortcutAction? {
        guard down, !chord else { return nil }
        chord = true
        return .toggle
    }
    public mutating func release(mode: RecordingMode) -> ShortcutAction? {
        guard down else { return nil }
        down = false
        if chord { chord = false; return nil }
        return mode == .pushToTalk ? .endHold : .toggle
    }
    public mutating func reset() { down = false; chord = false }
}

public struct UsageEntry: Codable, Identifiable {
    public var id: UUID
    public var date: Date
    public var words: Int
    public var duration: Double
    public init(date: Date = Date(), words: Int, duration: Double) {
        id = UUID(); self.date = date; self.words = max(0, words); self.duration = max(0, duration)
    }
}

public struct VocabularyEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var phrase: String
    public var heardAs: String
    public init(phrase: String, heardAs: String = "") {
        id = UUID(); self.phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        self.heardAs = heardAs.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum Vocabulary {
    public static func apply(_ entries: [VocabularyEntry], to text: String) -> String {
        // One pass prevents cascading replacements (A -> B -> C).
        let rules = entries.filter { !$0.heardAs.isEmpty && !$0.phrase.isEmpty }
            .sorted { $0.heardAs.count > $1.heardAs.count }
        guard !rules.isEmpty else { return text }
        let alternatives = rules.map { NSRegularExpression.escapedPattern(for: $0.heardAs) }.joined(separator: "|")
        guard let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])(?:\(alternatives))(?![\\p{L}\\p{N}_])", options: .caseInsensitive) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        var result = text
        for match in regex.matches(in: text, range: range).reversed() {
            guard let originalRange = Range(match.range, in: text), let replacementRange = Range(match.range, in: result) else { continue }
            let original = String(text[originalRange])
            if let rule = rules.first(where: { $0.heardAs.caseInsensitiveCompare(original) == .orderedSame }) {
                result.replaceSubrange(replacementRange, with: rule.phrase)
            }
        }
        return result
    }
}

public enum UsageStats {
    public static func words(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { _, _, _, _ in count += 1 }
        return count
    }
    public static func wpm(_ entries: [UsageEntry]) -> Int {
        let duration = entries.reduce(0) { $0 + $1.duration }
        return duration > 0 ? Int((Double(entries.reduce(0) { $0 + $1.words }) / duration * 60).rounded()) : 0
    }
    public static func dailyWords(_ entries: [UsageEntry], day: Date, calendar: Calendar = .current) -> Int {
        entries.filter { calendar.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.words }
    }
}
