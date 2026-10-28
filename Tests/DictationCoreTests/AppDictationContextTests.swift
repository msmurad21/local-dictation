import XCTest
@testable import DictationCore
final class AppDictationContextTests: XCTestCase {
    func testSpecificAppHintsAndCustomPriority() {
        let xcode = AppDictationContext(appName: "Xcode", bundleID: "com.apple.dt.Xcode", customTerms: "MyWidget, SwiftUI, MyWidget")
        XCTAssertEqual(xcode.terms.first, "MyWidget")
        XCTAssertEqual(xcode.terms.filter { $0 == "SwiftUI" }.count, 1)
        XCTAssertTrue(xcode.terms.contains("UIKit"))
        let php = AppDictationContext(appName: "PhpStorm", bundleID: "com.jetbrains.PhpStorm")
        XCTAssertTrue(php.terms.contains("Eloquent"))
        XCTAssertFalse(php.terms.contains("UIKit"))
    }
    func testUnknownAppIdentityAndBoundedTerms() {
        let value = AppDictationContext(appName: "Specialist App", bundleID: "example.specialist", customTerms: "Foobar\nQuux")
        XCTAssertEqual(value.category, .general)
        XCTAssertEqual(value.terms, ["Foobar", "Quux"])
        XCTAssertTrue(value.instructions.contains("Specialist App"))
        XCTAssertEqual(AppDictationContext.parseTerms(Array(repeating: "word", count: 100).joined(separator: ",")).count, 32)
    }
    func testGroundedCorrectionsAndProtectedText() {
        XCTAssertEqual(ContextualSpelling.decode("```json\n[{\"heard\":\"swift you eye\",\"term\":\"SwiftUI\"}]\n```").first?.term, "SwiftUI")
        let edit = ContextualSpelling.Edit(heard: "swift you eye", term: "SwiftUI")
        XCTAssertEqual(ContextualSpelling.apply([edit], to: "Create a swift you eye view.", terms: ["SwiftUI"]), "Create a SwiftUI view.")
        XCTAssertEqual(ContextualSpelling.apply([edit], to: "Create a swift you eye view.", terms: []), "Create a swift you eye view.")
        XCTAssertEqual(ContextualSpelling.apply([.init(heard: "tree", term: "seeder")], to: "The tree is tall.", terms: ["seeder"]), "The tree is tall.")
        XCTAssertEqual(ContextualSpelling.apply([.init(heard: "cedar", term: "seeder")], to: "The file is /cedar/config.", terms: ["seeder"]), "The file is /cedar/config.")
        XCTAssertEqual(ContextualSpelling.apply([edit], to: "He said \"swift you eye\".", terms: ["SwiftUI"]), "He said \"swift you eye\".")
        XCTAssertFalse(Polishing.acceptable("The Cedar Tree is Tall\n• The cedar tree is tall.", original: "The cedar tree is tall."))
    }
    func testRecoveryRetainsExactProfile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = try RecordingArchive(root: root)
        var item = try archive.create()
        item.appContext = AppDictationContext(appName: "Xcode", bundleID: "com.apple.dt.Xcode", customTerms: "MyWidget")
        try archive.save(item)
        XCTAssertEqual(archive.recordings().first?.appContext, item.appContext)
    }
}
