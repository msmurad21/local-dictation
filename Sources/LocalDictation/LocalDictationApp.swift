import SwiftUI
import DictationCore

@main struct LocalDictationMain {
    @MainActor static func main() {
        let args = CommandLine.arguments
        if args.contains("--prepare-model") || args.contains("--transcribe") || args.contains("--polish-text") || args.contains("--benchmark-audio") {
            Task {
            let engine = SpeechEngine()
            do {
                if let index = args.firstIndex(of: "--benchmark-audio"), index + 1 < args.count {
                    let start = ProcessInfo.processInfo.systemUptime
                    try await engine.load()
                    FileHandle.standardError.write(Data("Model load: \(ProcessInfo.processInfo.systemUptime-start)s\n".utf8))
                    for round in 0..<3 {
                        let start = ProcessInfo.processInfo.systemUptime
                        let text = try await engine.transcribe(URL(fileURLWithPath: args[index+1]))
                        let row: [String: Any] = ["round":round, "seconds":ProcessInfo.processInfo.systemUptime-start,"text":text]
                        print(String(data: try JSONSerialization.data(withJSONObject: row), encoding: .utf8)!)
                    }
                } else if let index = args.firstIndex(of: "--polish-text"), index + 1 < args.count {
                    let text = try String(contentsOfFile: args[index + 1], encoding: .utf8)
                    let result = try await TranscriptProcessor().process(text)
                    FileHandle.standardError.write(Data((result.note + "\n").utf8))
                    print(result.text)
                } else if args.contains("--prepare-model") {
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
