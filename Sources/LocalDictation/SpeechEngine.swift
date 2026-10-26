import Foundation
import WhisperKit
import DictationCore

enum AppError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

actor SpeechEngine {
    static let variant = "openai_whisper-base"
    let root: URL
    private var pipe: WhisperKit?

    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LocalDictation/Models")) {
        self.root = root
    }

    var modelFolder: URL { root.appendingPathComponent("models/argmaxinc/whisperkit-coreml/\(Self.variant)") }

    func prepare(progress: @escaping @Sendable (String) -> Void) async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        progress("Downloading multilingual speech model…")
        let folder = try await WhisperKit.download(variant: Self.variant, downloadBase: root) { value in
            progress("Downloading model: \(Int(value.fractionCompleted * 100))%")
        }
        guard folder.standardizedFileURL.path == modelFolder.standardizedFileURL.path else {
            throw AppError.message("Unexpected model location: \(folder.path)")
        }
        progress("Downloading tokenizer…")
        for name in ["tokenizer.json", "tokenizer_config.json"] {
            let destination = folder.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: destination.path) {
                let url = URL(string: "https://huggingface.co/openai/whisper-base/resolve/main/\(name)")!
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AppError.message("Tokenizer download failed.") }
                _ = try JSONSerialization.jsonObject(with: data)
                try data.write(to: destination, options: .atomic)
            }
        }
        try await load()
    }

    func load() async throws {
        if pipe != nil { return }
        for name in ["AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc", "tokenizer.json", "tokenizer_config.json"] {
            guard FileManager.default.fileExists(atPath: modelFolder.appendingPathComponent(name).path) else {
                throw AppError.message("Download the speech model first. Missing \(name).")
            }
        }
        // No speech service or cloud fallback. Model files are loaded from disk.
        pipe = try await WhisperKit(WhisperKitConfig(modelFolder: modelFolder.path, tokenizerFolder: modelFolder, verbose: false, prewarm: false, load: true, download: false))
    }

    func transcribe(_ url: URL, vocabulary: [String] = []) async throws -> String {
        let samples = try AudioProcessor.loadAudioAsFloatArray(fromPath: url.path)
        guard AudioGate.hasSignal(samples) else { return "" }
        try await load()
        guard let pipe else { throw AppError.message("Speech model is not loaded.") }
        let hints = vocabulary.filter { !$0.isEmpty }.prefix(80).joined(separator: ", ")
        let tokens = hints.isEmpty ? nil : pipe.tokenizer.map { Array($0.encode(text: "Vocabulary: " + hints).suffix(200)) }
        let results = try await pipe.transcribe(audioArray: samples, decodeOptions: DecodingOptions(task: .transcribe, detectLanguage: true, skipSpecialTokens: true, withoutTimestamps: true, promptTokens: tokens, suppressBlank: true))
        return results.map(\.text).joined(separator: " ")
    }
}
