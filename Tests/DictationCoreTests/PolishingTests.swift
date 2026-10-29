import XCTest
@testable import DictationCore

final class PolishingTests: XCTestCase {
    func testAcceptsGrammarAndLists() {
        XCTAssertTrue(Polishing.acceptable("I received your message.", original: "i recieved your mesage"))
        XCTAssertTrue(Polishing.acceptable("1. Review the draft.\n2. Send it.", original: "review the draft send it"))
        XCTAssertTrue(Polishing.acceptable("• Pay $25.\n• Email sam@example.com.", original: "pay $25 email sam@example.com"))
    }
    func testPreservesWordingOrderAndRepetitions() {
        XCTAssertFalse(Polishing.acceptable("We need to create a SwiftUI view.", original: "Create a SwiftUI view."))
        XCTAssertFalse(Polishing.acceptable("Send it after review.", original: "Review it after sending."))
        XCTAssertFalse(Polishing.acceptable("I want this because it matters.", original: "So I really want this, I want this because it matters."))
        XCTAssertTrue(Polishing.acceptable("So, I really want this.\n\nI want this because it matters.", original: "So I really want this I want this because it matters"))
        XCTAssertTrue(Polishing.acceptable("We need:\n• apples,\n• bananas,\n• and milk.", original: "We need apples bananas and milk."))
    }
    func testRejectsChangedNumbersAddressesAndEmptyOutput() {
        XCTAssertFalse(Polishing.acceptable("Pay $50.", original: "pay $25"))
        XCTAssertFalse(Polishing.acceptable("Email bob@example.com.", original: "email sam@example.com"))
        XCTAssertFalse(Polishing.acceptable("", original: "hello there"))
        XCTAssertFalse(Polishing.acceptable("```hello```", original: "hello"))
        XCTAssertFalse(Polishing.acceptable("Yes.", original: "Please review all of the documents before sending the final version to the client."))
    }
    func testChunkingPreservesEveryCharacter() {
        for text in [String(repeating: "Hello, world. ", count: 300), String(repeating: "你", count: 3000), "One short sentence."] {
            let chunks = Polishing.chunks(text)
            XCTAssertEqual(chunks.joined(), text)
            XCTAssertTrue(chunks.allSatisfy { $0.count <= 1200 })
        }
    }
}
