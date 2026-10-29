import Foundation
import DictationCore

@MainActor final class LocalStore: ObservableObject {
    struct UsedApp: Codable, Identifiable {
        var id: String
        var name: String
        var words: Int
        var dictations: Int
        var lastUsed: Date
    }
    struct DataFile: Codable {
        var sessions: [UsageEntry] = []
        var vocabulary: [VocabularyEntry] = []
        var apps: [UsedApp]?
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
    func recordApp(name: String, bundleID: String, words: Int) {
        guard !bundleID.isEmpty else { return }
        var apps = data.apps ?? []
        if let index = apps.firstIndex(where: { $0.id == bundleID }) {
            apps[index].name = name; apps[index].words += words
            apps[index].dictations += 1; apps[index].lastUsed = Date()
        } else { apps.append(UsedApp(id: bundleID, name: name, words: words, dictations: 1, lastUsed: Date())) }
        data.apps = apps; save()
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
