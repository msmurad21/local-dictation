"""Benchmark the actual app cleanup processor with synthetic transcripts."""
import argparse, json, subprocess, tempfile
from pathlib import Path
parser = argparse.ArgumentParser()
parser.add_argument("--cases", type=Path, default=Path(__file__).with_name("cases.json"))
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
files = ["Polishing.swift", "VoiceEdits.swift", "DictationContext.swift", "AppDictationContext.swift", "ContextualSpelling.swift", "FastCleanup.swift", "TranscriptLayout.swift"]
parts = [(root/"Sources/DictationCore"/name).read_text() for name in files]
parts.append((root/"Sources/LocalDictation/TranscriptProcessor.swift").read_text().replace("import DictationCore", ""))
# The 500 ms prewarm lead time represents work done while the user records.
parts.append('''
struct Case: Codable { let id: String; let text: String; let vocabulary: [String] }
Task {
 let cases = try! JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
 let processor = TranscriptProcessor()
 for round in 0..<2 { for c in cases {
  await processor.prewarm()
  try? await Task.sleep(for: .milliseconds(500))
  let start = ProcessInfo.processInfo.systemUptime
  do {
   let result = try await processor.process(c.text, vocabulary: c.vocabulary)
   let row: [String: Any] = ["id":c.id, "round":round, "seconds":ProcessInfo.processInfo.systemUptime-start, "text":result.text, "note":result.note]
   print(String(data: try! JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]), encoding: .utf8)!)
  } catch { print(error) }
 }}
 exit(0)
}
dispatchMain()
''')
with tempfile.TemporaryDirectory(prefix="dictation-benchmark-") as folder:
    source = Path(folder)/"benchmark.swift"
    source.write_text("\n".join(parts))
    subprocess.run(["swift", str(source), str(args.cases.resolve())], check=True)
