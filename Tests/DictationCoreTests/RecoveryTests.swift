import XCTest
@testable import DictationCore

final class RecoveryTests: XCTestCase {
    func testDecoderSilenceMarkerIsNotPasted() {
        XCTAssertEqual(Transcript.clean("Hello. [BLANK_AUDIO]"), "Hello.")
    }
    func testPendingRecordingSurvivesReopenAndKeepsAudio() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = try RecordingArchive(root: root)
        var item = try archive.create()
        let audio = Data([1, 2, 3, 4])
        try audio.write(to: archive.audioURL(item))
        item.duration = 42; try archive.save(item)
        let reopened = try RecordingArchive(root: root)
        XCTAssertEqual(reopened.recordings(), [item])
        XCTAssertEqual(try Data(contentsOf: reopened.audioURL(item)), audio)
        item.state = "completed"; item.counted = true; try reopened.save(item)
        XCTAssertTrue(try XCTUnwrap(reopened.recordings().first).counted)
        try reopened.remove(item)
        XCTAssertTrue(reopened.recordings().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reopened.audioURL(item).path))
    }
    func testRetentionRemovesExpiredAudioAndCapsCount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = try RecordingArchive(root: root)
        let now = Date()
        let old = try archive.create(now: now.addingTimeInterval(-90_000))
        try Data([1]).write(to: archive.audioURL(old))
        for index in 0..<35 { _ = try archive.create(now: now.addingTimeInterval(Double(index))) }
        try archive.prune(now: now.addingTimeInterval(40))
        XCTAssertEqual(archive.recordings().count, 30)
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.audioURL(old).path))
    }
    func testRejectsDroppedIntroduction() {
        XCTAssertFalse(Polishing.acceptable("1. Review the draft.\n2. Fix the mistakes.\n3. Send it for approval.", original: "to publish the release review the draft then fix the mistakes and finally send it for approval"))
    }
    func testRejectsDroppedMiddlePointAndEnding() {
        let original = "Please review the proposal carefully tomorrow morning before meeting the client. Keep the original budget unchanged and send the final report to Sarah after lunch."
        XCTAssertFalse(Polishing.acceptable("Please review the proposal carefully tomorrow morning before meeting the client. Keep the original budget unchanged.", original: original))
        XCTAssertFalse(Polishing.acceptable("Please review the proposal carefully tomorrow morning before meeting the client. Send the final report to Sarah after lunch.", original: original))
        XCTAssertTrue(Polishing.acceptable("• Please review the proposal carefully tomorrow morning before meeting the client.\n• Keep the original budget unchanged.\n• And send the final report to Sarah after lunch.", original: original))
    }
}
