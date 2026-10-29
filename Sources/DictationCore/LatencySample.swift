import Foundation

public struct LatencySample: Codable, Sendable {
    public let transcription: Double
    public let cleanup: Double
    public let paste: Double
    public let total: Double
    public let date: Date
    public init(transcription: Double, cleanup: Double, paste: Double, total: Double, date: Date = Date()) {
        self.transcription = max(0, transcription); self.cleanup = max(0, cleanup)
        self.paste = max(0, paste); self.total = max(0, total); self.date = date
    }
}
