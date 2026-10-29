import Foundation
import DictationCore

@MainActor final class LocalStore: ObservableObject {
    struct DataFile: Codable {
        var sessions: [UsageEntry] = []
        var vocabulary: [VocabularyEntry] = []
        var apps: [UsedApp]?
        var appEvents: [AppUsageEvent]?
    }
    @Published private(set) var data = DataFile()
    @Published var saveError: String?
    private let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LocalDictation/usage.json")
    init() {
        if FileManager.default.fileExists(atPath: url.path) {
            do { data = try JSONDecoder().decode(DataFile.self, from: Data(contentsOf: url)) }
            catch { saveError = "Could not read saved statistics: \(error.localizedDescription)" }
        }
    }
    func record(words: Int, duration: Double) {
        guard words > 0 else { return }
        data.sessions.append(UsageEntry(words: words, duration: duration)); save()
    }
    func recordApp(name: String, bundleID: String, words: Int, duration: Double?, recordingID: UUID?) {
        var apps = data.apps ?? [], events = data.appEvents ?? []
        AppUsage.record(apps: &apps, events: &events, name: name, bundleID: bundleID, words: words, duration: duration, recordingID: recordingID)
        data.apps = apps; data.appEvents = events; save()
    }
    func add(phrase: String, heardAs: String) {
        let entry = VocabularyEntry(phrase: phrase, heardAs: heardAs)
        guard !entry.phrase.isEmpty else { return }
        if let index = data.vocabulary.firstIndex(where: { $0.phrase.caseInsensitiveCompare(entry.phrase) == .orderedSame }) { data.vocabulary[index] = entry }
        else { data.vocabulary.append(entry) }
        save()
    }
    func remove(_ id: UUID) { data.vocabulary.removeAll { $0.id == id }; save() }
    private func save() {
        // Preserve a corrupt existing file rather than silently overwriting it.
        guard saveError == nil else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(data).write(to: url, options: .atomic)
        } catch { saveError = "Could not save local data: \(error.localizedDescription)" }
    }
}
