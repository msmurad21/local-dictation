import Foundation

public enum Transcript {
    /// Preserve wording and paragraph boundaries. No speculative rewriting.
    public static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "[BLANK_AUDIO]", with: "")
            .replacingOccurrences(of: "<\\|[^|]*\\|>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum AudioGate {
    /// Reject digital silence and a disconnected input, not quiet speech.
    /// This is an energy floor, not a speech-versus-background-noise classifier.
    public static func hasSignal(_ samples: [Float]) -> Bool {
        guard !samples.isEmpty, samples.allSatisfy({ $0.isFinite }) else { return false }
        let energy = samples.reduce(0.0) { $0 + Double($1) * Double($1) } / Double(samples.count)
        return energy > 0.000000001
    }
}

/// A release during the asynchronous microphone prompt must cancel the start.
public struct HoldGate {
    public private(set) var generation = 0
    public private(set) var held = false
    public init() {}
    public mutating func press() -> Int { generation += 1; held = true; return generation }
    public mutating func release() { held = false }
    public func mayStart(_ token: Int) -> Bool { held && token == generation }
}
