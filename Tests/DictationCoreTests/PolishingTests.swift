import XCTest
@testable import DictationCore

final class PolishingTests: XCTestCase {
    func testAcceptsGrammarAndLists() {
        XCTAssertTrue(Polishing.acceptable("I received your message.", original: "um i recieved your mesage"))
        XCTAssertTrue(Polishing.acceptable("1. Review the draft.\n2. Send it.", original: "numbered list first review the draft second send it"))
        XCTAssertTrue(Polishing.acceptable("• Pay $25.\n• Email sam@example.com.", original: "bullet points pay $25 email sam@example.com"))
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
