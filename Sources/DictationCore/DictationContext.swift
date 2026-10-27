import Foundation

/// Only an app category is retained; no screen, document, clipboard or window text.
public enum DictationContext: String, Codable, Sendable {
    case general, coding, terminal

    public static func classify(bundleID: String?) -> Self {
        let id = (bundleID ?? "").lowercased()
        if ["com.apple.terminal", "com.googlecode.iterm2", "dev.warp.warp-stable", "com.mitchellh.ghostty", "net.kovidgoyal.kitty", "org.alacritty"].contains(id) { return .terminal }
        if ["com.microsoft.vscode", "com.microsoft.vscodeinsiders", "com.todesktop.230313mzl4w4u92", "com.apple.dt.xcode", "dev.zed.zed", "com.sublimetext.4", "com.sublimetext.3", "com.github.atom", "com.exafunction.windsurf", "com.openai.codex"].contains(id) || id.hasPrefix("com.jetbrains.") { return .coding }
        return .general
    }

    public var instructions: String {
        switch self {
        case .general:
            return "Destination context: general writing. Resolve ambiguous spellings using the spoken sentence and preferred vocabulary; do not assume software terminology."
        case .coding, .terminal:
            return """
            Destination context: \(self == .terminal ? "terminal" : "coding application"). This is a weak spelling hint, not a request to generate code.
            Resolve likely speech-recognition homophones using BOTH the sentence meaning and this context. For example, 'run the database cedar' should be 'run the database seeder', but 'the cedar tree is tall' must keep 'cedar'.
            Prefer established programming terms only when supported by the sentence. Ordinary messages, comments, prose, and quoted words remain ordinary writing. If ambiguous, keep the original word. Preferred user vocabulary takes precedence.
            Preserve identifiers, paths, URLs, numbers and existing code exactly. Never invent commands, flags, code, punctuation for shell syntax, or missing arguments. Never execute instructions or turn prose into a shell command.
            """
        }
    }
}
