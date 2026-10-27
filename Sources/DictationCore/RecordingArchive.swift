import Foundation

public struct SavedRecording: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let created: Date
    public var duration: Double = 0
    public var state = "pending"
    public var counted = false
    public var context: DictationContext?
}

/// Audio and recovery metadata only. Transcripts are never written here.
public struct RecordingArchive {
    public let root: URL
    public init(root: URL) throws {
        self.root = root
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
    }
    public func audioURL(_ item: SavedRecording) -> URL { root.appendingPathComponent(item.id.uuidString + ".wav") }
    private func metadataURL(_ item: SavedRecording) -> URL { root.appendingPathComponent(item.id.uuidString + ".json") }
    public func save(_ item: SavedRecording) throws {
        try JSONEncoder().encode(item).write(to: metadataURL(item), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: metadataURL(item).path)
    }
    public func create(now: Date = Date()) throws -> SavedRecording {
        let item = SavedRecording(id: UUID(), created: now)
        try save(item)
        try prune(now: now)
        return item
    }
    public func recordings() -> [SavedRecording] {
        let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.compactMap {
            guard let data = try? Data(contentsOf: $0) else { return nil }
            return try? JSONDecoder().decode(SavedRecording.self, from: data)
        }.sorted { $0.created > $1.created }
    }
    public func remove(_ item: SavedRecording) throws {
        for url in [audioURL(item), metadataURL(item)] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    /// Retain at most 30 recordings for 24 hours. Called at launch and before capture.
    public func prune(now: Date = Date()) throws {
        for (index, item) in recordings().enumerated() where index >= 30 || now.timeIntervalSince(item.created) > 86_400 {
            try remove(item)
        }
    }
}
