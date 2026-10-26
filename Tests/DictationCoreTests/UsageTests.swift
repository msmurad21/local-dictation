import XCTest
@testable import DictationCore

final class UsageTests: XCTestCase {
    func testFnSpaceLatchesAndReleaseDoesNotStop() {
        var router = ShortcutRouter()
        XCTAssertEqual(router.press(mode: .pushToTalk), .beginHold)
        XCTAssertEqual(router.space(), .toggle)
        XCTAssertNil(router.space())
        XCTAssertNil(router.release(mode: .pushToTalk))
        XCTAssertEqual(router.press(mode: .pushToTalk), .beginHold)
        XCTAssertEqual(router.release(mode: .pushToTalk), .endHold)
    }
    func testToggleModeDefersUntilReleaseToAvoidDoubleToggleOnChord() {
        var router = ShortcutRouter()
        XCTAssertNil(router.press(mode: .toggle))
        XCTAssertEqual(router.release(mode: .toggle), .toggle)
        XCTAssertNil(router.press(mode: .toggle))
        XCTAssertEqual(router.space(), .toggle)
        XCTAssertNil(router.release(mode: .toggle))
    }
    func testFnFinishesHandsFreeAndConsumesReleaseAndSpace() {
        for mode in RecordingMode.allCases {
            var router = ShortcutRouter()
            _ = router.press(mode: mode)
            XCTAssertEqual(router.space(), .toggle)
            XCTAssertNil(router.release(mode: mode))
            XCTAssertEqual(router.press(mode: mode, finishingHandsFree: true), .finish)
            XCTAssertNil(router.press(mode: mode, finishingHandsFree: true))
            XCTAssertNil(router.space())
            XCTAssertNil(router.release(mode: mode))
            XCTAssertEqual(router.press(mode: .pushToTalk), .beginHold)
            XCTAssertEqual(router.release(mode: .pushToTalk), .endHold)
        }
    }
    func testKeyRepeatDoesNotRestartRecording() {
        var router = ShortcutRouter()
        XCTAssertEqual(router.press(mode: .pushToTalk), .beginHold)
        XCTAssertNil(router.press(mode: .pushToTalk))
        XCTAssertEqual(router.release(mode: .pushToTalk), .endHold)
        XCTAssertNil(router.release(mode: .pushToTalk))
    }
    func testVocabularyUsesBoundariesAndLiteralReplacement() {
        let entries = [VocabularyEntry(phrase: "Kubernetes", heardAs: "cube er netties"), VocabularyEntry(phrase: "$&", heardAs: "cash")]
        XCTAssertEqual(Vocabulary.apply(entries, to: "Cube er netties, cash, cashmere."), "Kubernetes, $&, cashmere.")
    }
    func testVocabularyDoesNotCascade() {
        let entries = [VocabularyEntry(phrase: "beta", heardAs: "alpha"), VocabularyEntry(phrase: "gamma", heardAs: "beta")]
        XCTAssertEqual(Vocabulary.apply(entries, to: "alpha beta"), "beta gamma")
    }
    func testWeightedWPMAndCalendarDays() {
        let entries = [UsageEntry(words: 100, duration: 60), UsageEntry(words: 100, duration: 120)]
        XCTAssertEqual(UsageStats.wpm(entries), 67)
        XCTAssertEqual(UsageStats.wpm([]), 0)
        XCTAssertEqual(UsageStats.words(in: "Hello, world!"), 2)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 5 * 3600)!
        let first = Date(timeIntervalSince1970: 0)
        let dayLater = first.addingTimeInterval(86400)
        XCTAssertEqual(UsageStats.dailyWords([UsageEntry(date: first, words: 10, duration: 1), UsageEntry(date: dayLater, words: 20, duration: 1)], day: first, calendar: calendar), 10)
    }
    func testSavedUsageContainsNoTranscript() throws {
        let data = try JSONEncoder().encode(UsageEntry(words: 9, duration: 3))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["id", "date", "words", "duration"])
    }
}
