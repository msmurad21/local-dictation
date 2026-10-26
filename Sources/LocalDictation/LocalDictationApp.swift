import SwiftUI
import DictationCore

@main struct LocalDictationMain {
    @MainActor static func main() {
        let args = CommandLine.arguments
        if args.contains("--prepare-model") || args.contains("--transcribe") {
            Task {
            let engine = SpeechEngine()
            do {
                if args.contains("--prepare-model") {
                    try await engine.prepare { message in FileHandle.standardError.write(Data((message + "\n").utf8)) }
                    print("Model ready")
                } else if let index = args.firstIndex(of: "--transcribe"), index + 1 < args.count {
                    print(Transcript.clean(try await engine.transcribe(URL(fileURLWithPath: args[index + 1]))))
                } else { throw AppError.message("Usage: LocalDictation --transcribe AUDIO_FILE") }
            } catch { FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8)); exit(1) }
            exit(0)
            }
            dispatchMain()
        } else {
            let application = NSApplication.shared
            let delegate = AppDelegate()
            application.delegate = delegate
            application.setActivationPolicy(.accessory)
            withExtendedLifetime(delegate) { application.run() }
        }
    }
}
