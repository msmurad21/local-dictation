import XCTest
@testable import DictationCore

final class VoiceEditsTests: XCTestCase {
    func testAdditionalCuesAndFencedCorrections() throws {
        XCTAssertEqual(VoiceEdits.apply("Please delete that file tomorrow."), "Please delete that file tomorrow.")
        XCTAssertEqual(VoiceEdits.apply("Keep this. Wrong line. Undo that. Next idea."), "Keep this.  Next idea.")
        XCTAssertEqual(VoiceEdits.apply("Wrong line. Scratch that last sentence. Next idea."), "Next idea.")
        XCTAssertEqual(VoiceEdits.formatting("Apples and milk. Make this a bullet list.").style, "BULLETS")
        XCTAssertEqual(VoiceEdits.formatting("Apples and milk. Format as a numbered list.").style, "STEPS")
        XCTAssertTrue(VoiceEdits.formatting("Hello. New paragraph. How are you?").text.contains("\n\n"))
        XCTAssertEqual(VoiceEdits.formatting("We need a new paragraph here.").text, "We need a new paragraph here.")
        let data = VoiceEdits.jsonData("```json\n[{\"command\":\"Make that Tuesday.\",\"target\":\"Monday\",\"replacement\":\"Tuesday\"}]\n```")!
        XCTAssertEqual(try JSONDecoder().decode([VoiceEdits.Correction].self, from: data).count, 1)
    }

    func testScratchSentenceAndContinue() {
        XCTAssertEqual(VoiceEdits.apply("Keep this sentence. Remove this one. Scratch the last line. Add a new idea."), "Keep this sentence.  Add a new idea.")
        XCTAssertEqual(VoiceEdits.apply("Meet on Monday scratch that Meet on Tuesday."), "Meet on Tuesday.")
    }
    func testWordAndClear() {
        XCTAssertEqual(VoiceEdits.apply("Hello world delete the last word"), "Hello")
        XCTAssertEqual(VoiceEdits.apply("Discard everything. Start over. A fresh thought."), "A fresh thought.")
        XCTAssertEqual(VoiceEdits.apply("A thought. Clear everything."), "")
    }
    func testQuotedAndReportedCommandsStayLiteral() {
        for input in ["Do not scratch the last line.", "Never delete the last word.", "Don’t scratch that.", "\"Don’t scratch that\"", "He said scratch the last line.", "She said ‘scratch that’.", "Write the phrase scratch that.", "He said \"delete the last word\"."] {
            XCTAssertEqual(VoiceEdits.apply(input), input)
        }
    }
    func testCleanupCannotDuplicateCorrectedText() {
        XCTAssertFalse(Polishing.acceptable("Meet on Tuesday at noon. Bring the report.\nMeeting\n• Meet on Tuesday at noon.\n• Bring the report.", original: "Meet on Tuesday at noon. Bring the report."))
    }
    func testFormattingCommandsAreConsumed() {
        let edited = VoiceEdits.formatting("We need apples and milk. Make those bullet points.")
        XCTAssertEqual(edited.text, "We need apples and milk.")
        XCTAssertEqual(edited.style, "BULLETS")
        XCTAssertNil(VoiceEdits.formatting("He said make those bullet points.").style)
    }
    func testAnchoredCorrectionPreservesOtherText() {
        let text = "Meet on Monday at noon. Actually make that Tuesday. Bring the report."
        let result = VoiceEdits.correct(.init(command: "Actually make that Tuesday.", target: "Monday", replacement: "Tuesday"), in: text)
        XCTAssertEqual(VoiceEdits.correct(.init(command: "Actually make that Tuesday.", target: "Monday at noon.", replacement: "Tuesday"), in: text), "Meet on Tuesday at noon.  Bring the report.")
        XCTAssertEqual(result, "Meet on Tuesday at noon.  Bring the report.")
        XCTAssertNil(VoiceEdits.correct(.init(command: "Actually make that Tuesday.", target: "Monday", replacement: "Friday"), in: text))
        XCTAssertNil(VoiceEdits.correct(.init(command: "Actually make that Tuesday.", target: "report", replacement: "Tuesday"), in: text))
        XCTAssertNil(VoiceEdits.correct(.init(command: "make that Tuesday", target: "Monday", replacement: "Tuesday"), in: "Monday. He said make that Tuesday."))
    }
}
