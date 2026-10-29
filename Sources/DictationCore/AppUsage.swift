import Foundation

public struct UsedApp: Codable, Identifiable {
    public var id: String
    public var name: String
    public var words: Int
    public var dictations: Int
    public var lastUsed: Date
    public var duration: Double?
}
public struct AppUsageEvent: Codable, Identifiable {
    public var id: UUID
    public var recordingID: UUID?
    public var appID: String
    public var date: Date
    public var words: Int
    public var duration: Double?
}
public enum AppUsage {
    /// A recording pasted again into the same app must not inflate dictation stats.
    public static func record(apps: inout [UsedApp], events: inout [AppUsageEvent], name: String, bundleID: String, words: Int, duration: Double?, recordingID: UUID?, now: Date = Date()) {
        guard !bundleID.isEmpty, words > 0 else { return }
        if let recordingID, events.contains(where: { $0.recordingID == recordingID && $0.appID == bundleID }) { return }
        let seconds = duration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        events.append(AppUsageEvent(id: UUID(), recordingID: recordingID, appID: bundleID, date: now, words: words, duration: seconds))
        if let index = apps.firstIndex(where: { $0.id == bundleID }) {
            apps[index].name = name; apps[index].words += words; apps[index].dictations += 1; apps[index].lastUsed = now
            if let seconds { apps[index].duration = (apps[index].duration ?? 0) + seconds }
        } else { apps.append(UsedApp(id: bundleID, name: name, words: words, dictations: 1, lastUsed: now, duration: seconds)) }
    }
    public static func durationLabel(_ duration: Double?) -> String {
        guard let duration, duration.isFinite, duration > 0 else { return "—" }
        let seconds = Int(duration.rounded())
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)m \(seconds % 60)s"
    }
}
