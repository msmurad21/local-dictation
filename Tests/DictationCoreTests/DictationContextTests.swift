import XCTest
@testable import DictationCore

final class DictationContextTests: XCTestCase {
    func testKnownAppsAndUnknownFallback() {
        XCTAssertEqual(DictationContext.classify(bundleID: "com.apple.Terminal"), .terminal)
        XCTAssertEqual(DictationContext.classify(bundleID: "com.googlecode.iterm2"), .terminal)
        XCTAssertEqual(DictationContext.classify(bundleID: "com.microsoft.VSCode"), .coding)
        XCTAssertEqual(DictationContext.classify(bundleID: "com.jetbrains.pycharm"), .coding)
        XCTAssertEqual(DictationContext.classify(bundleID: "com.apple.Safari"), .general)
        XCTAssertEqual(DictationContext.classify(bundleID: "example.vscode.fake"), .general)
        XCTAssertEqual(DictationContext.classify(bundleID: nil), .general)
    }
    func testContextualSpellingAndUnwantedCommentary() {
        XCTAssertTrue(Polishing.acceptable("Run the database seeder before the tests.", original: "Run the database cedar before the tests."))
        XCTAssertFalse(Polishing.acceptable("Heading: Spelling\n\nTranscript:\nThe cedar tree is tall.", original: "The cedar tree is tall."))
    }
    func testLegacyMetadataAndRetryContext() throws {
        let old = #"{"id":"00000000-0000-0000-0000-000000000001","created":0,"duration":2,"state":"pending","counted":false}"#.data(using: .utf8)!
        var item = try JSONDecoder().decode(SavedRecording.self, from: old)
        XCTAssertNil(item.context)
        item.context = .terminal
        XCTAssertEqual(try JSONDecoder().decode(SavedRecording.self, from: JSONEncoder().encode(item)).context, .terminal)
    }
}
