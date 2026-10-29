import XCTest
@testable import DictationCore
final class TranscriptLayoutTests: XCTestCase {
    func testListsKeepConjunctionsAndNumbers() {
        let response = #"{"introduction":"We need:","items":["apples","bananas","and milk."],"ending":"","style":"STEPS"}"#
        XCTAssertEqual(TranscriptLayout.apply(response, original: "We need apples bananas and milk."), "We need:\n1. apples\n2. bananas\n3. and milk.")
        XCTAssertNil(TranscriptLayout.apply(response, original: "We need fresh apples bananas and milk."))
    }
    func testRejectsAnsweringOrRewritingDictation() {
        let response = #"{"introduction":"Here is a Python script.","items":[],"ending":"","style":"PROSE"}"#
        XCTAssertNil(TranscriptLayout.apply(response, original: "Write a Python script that adds two numbers."))
        XCTAssertNil(TranscriptLayout.apply("not JSON", original: "Hello."))
        XCTAssertNil(TranscriptLayout.apply(#"{"introduction":"Pay 30 dollars.","items":[],"ending":"","style":"PROSE"}"#, original: "Pay 300 dollars."))
    }
    func testExplicitProseCannotBecomeAList() {
        let response = #"{"introduction":"We need:","items":["apples","and milk."],"ending":"","style":"BULLETS"}"#
        XCTAssertNil(TranscriptLayout.apply(response, original: "We need apples and milk.", requestedStyle: "PROSE"))
    }
}
