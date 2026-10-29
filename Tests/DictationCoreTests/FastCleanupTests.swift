import XCTest
@testable import DictationCore
final class FastCleanupTests: XCTestCase {
    func testVocabularyCandidateSkipsUnrelatedAndExactTerms() {
        XCTAssertFalse(FastCleanup.hasVocabularyCandidate("Review the proposal.", terms: ["SwiftUI", "seeder"]))
        XCTAssertFalse(FastCleanup.hasVocabularyCandidate("SwiftUI", terms: ["SwiftUI"]))
        XCTAssertFalse(FastCleanup.hasVocabularyCandidate("", terms: ["SwiftUI"]))
    }
    func testVocabularyCandidateKeepsPhoneticMismatches() {
        XCTAssertTrue(FastCleanup.hasVocabularyCandidate("Create a swift you eye view.", terms: ["SwiftUI"]))
        XCTAssertTrue(FastCleanup.hasVocabularyCandidate("Create a cedar for the database.", terms: ["seeder"]))
    }
}
