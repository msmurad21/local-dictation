import XCTest
@testable import DictationCore

final class UpdatePolicyTests: XCTestCase {
    func testRequiresHTTPSAndPublicSigningKey() {
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        XCTAssertTrue(UpdatePolicy.validConfiguration(feed: "https://updates.example.org/appcast.xml", publicKey: key))
        for feed in [nil, "", "http://updates.example.org/appcast.xml", "https://user:password@example.org/appcast.xml"] {
            XCTAssertFalse(UpdatePolicy.validConfiguration(feed: feed, publicKey: key))
        }
        XCTAssertFalse(UpdatePolicy.validConfiguration(feed: "https://example.org/feed", publicKey: "placeholder"))
    }
    func testEveryActiveStatePreventsRestart() {
        XCTAssertTrue(UpdatePolicy.mayRestart(recording: false, starting: false, busy: false, submitting: false, hasUnpastedText: false, dashboardActive: false))
        for index in 0..<6 {
            var states = Array(repeating: false, count: 6); states[index] = true
            XCTAssertFalse(UpdatePolicy.mayRestart(recording: states[0], starting: states[1], busy: states[2], submitting: states[3], hasUnpastedText: states[4], dashboardActive: states[5]))
        }
    }
}
