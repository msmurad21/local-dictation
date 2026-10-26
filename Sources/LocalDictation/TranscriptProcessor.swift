import Foundation
import DictationCore
#if canImport(FoundationModels)
import FoundationModels
#endif

struct PolishedTranscript: Sendable {
    let text: String
    let note: String
}

actor TranscriptProcessor {
    static var availability: String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return "On-device cleanup is ready."
            case .unavailable(.appleIntelligenceNotEnabled): return "Enable Apple Intelligence in System Settings to use cleanup."
            case .unavailable(.modelNotReady): return "Apple Intelligence is still preparing its on-device model."
            case .unavailable(.deviceNotEligible): return "On-device cleanup requires an Apple Intelligence-capable Mac."
            @unknown default: return "The on-device cleanup model is unavailable."
            }
        }
        #endif
        return "AI cleanup requires macOS 26+ and a build made with Xcode 26+. Original dictation still works."
    }

    func process(_ original: String, vocabulary: [String] = []) async throws -> PolishedTranscript {
        guard !original.isEmpty else { return PolishedTranscript(text: "", note: "") }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *), SystemLanguageModel.default.availability == .available {
            do {
                var edited: [String] = []
                for chunk in Polishing.chunks(original) {
                    try Task.checkCancellation()
                    let session = LanguageModelSession(
                        model: SystemLanguageModel(guardrails: .permissiveContentTransformations),
                        instructions: Polishing.instructions)
                    // A new session per chunk prevents previous dictations leaking into this one.
                    let hints = vocabulary.prefix(40).joined(separator: ", ").prefix(500)
                    let response = try await session.respond(to: "Preferred spellings (only if spoken): \(hints)\n\nTranscript to edit:\n\(chunk)",
                        options: GenerationOptions(temperature: 0, maximumResponseTokens: 1600))
                    try Task.checkCancellation()
                    let output = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard Polishing.acceptable(output, original: chunk) else {
                        return PolishedTranscript(text: original, note: "Kept the original: cleanup changed protected details or returned an incomplete result.")
                    }
                    edited.append(output)
                }
                let result = edited.joined(separator: "\n\n")
                guard Polishing.acceptable(result, original: original) else {
                    return PolishedTranscript(text: original, note: "Kept the original: cleanup changed protected details.")
                }
                return PolishedTranscript(text: result, note: "Cleaned up locally · spelling, grammar and formatting")
            } catch is CancellationError { throw CancellationError() }
            catch {
                return PolishedTranscript(text: original, note: "Cleanup could not finish. Kept the original transcript.")
            }
        }
        #endif
        return PolishedTranscript(text: original, note: Self.availability + " Kept the original transcript.")
    }
}
