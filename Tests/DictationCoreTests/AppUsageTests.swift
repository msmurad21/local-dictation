import XCTest
@testable import DictationCore
final class AppUsageTests: XCTestCase {
    func testLegacyHistoryLoadsWithoutDuration() throws {
        let data = #"{"id":"example.app","name":"App","words":20,"dictations":2,"lastUsed":0}"#.data(using: .utf8)!
        let app = try JSONDecoder().decode(UsedApp.self, from: data)
        XCTAssertNil(app.duration)
        XCTAssertEqual(app.words, 20)
    }
    func testAggregationDuplicatePasteAndSeparateApp() {
        var apps: [UsedApp] = []; var events: [AppUsageEvent] = []
        let recording = UUID(), now = Date(timeIntervalSince1970: 100)
        for _ in 0..<2 { AppUsage.record(apps: &apps, events: &events, name: "Editor", bundleID: "editor", words: 40, duration: 12, recordingID: recording, now: now) }
        XCTAssertEqual(apps[0].words, 40); XCTAssertEqual(apps[0].dictations, 1)
        XCTAssertEqual(apps[0].duration, 12); XCTAssertEqual(apps[0].lastUsed, now)
        AppUsage.record(apps: &apps, events: &events, name: "Notes", bundleID: "notes", words: 40, duration: 12, recordingID: recording, now: now)
        XCTAssertEqual(apps.count, 2); XCTAssertEqual(events.count, 2)
        AppUsage.record(apps: &apps, events: &events, name: "Editor", bundleID: "editor", words: 10, duration: 4, recordingID: UUID(), now: now)
        XCTAssertEqual(apps[0].words, 50); XCTAssertEqual(apps[0].duration, 16)
    }
    func testInvalidAndUnknownDurations() {
        XCTAssertEqual(AppUsage.durationLabel(nil), "—")
        XCTAssertEqual(AppUsage.durationLabel(75), "1m 15s")
        var apps: [UsedApp] = []; var events: [AppUsageEvent] = []
        AppUsage.record(apps: &apps, events: &events, name: "App", bundleID: "app", words: 10, duration: .nan, recordingID: nil)
        XCTAssertNil(apps[0].duration)
        AppUsage.record(apps: &apps, events: &events, name: "App", bundleID: "app", words: 0, duration: 10, recordingID: nil)
        XCTAssertEqual(events.count, 1)
    }
}
