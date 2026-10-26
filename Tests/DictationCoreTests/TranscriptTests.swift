import XCTest
@testable import DictationCore

final class TranscriptTests: XCTestCase {
    func testSilenceCannotReachDecoder() {
        XCTAssertFalse(AudioGate.hasSignal([]))
        XCTAssertFalse(AudioGate.hasSignal(Array(repeating: 0, count: 48000)))
        XCTAssertFalse(AudioGate.hasSignal([.nan]))
        XCTAssertTrue(AudioGate.hasSignal([0.001, -0.001, 0.002, -0.002]))
    }
    func testPreservesCorrectionsAndParagraphs() {
        XCTAssertEqual(Transcript.clean("  Meet Friday—actually Monday.\nDon't remove 'um' from this quote.  "), "Meet Friday—actually Monday.\nDon't remove 'um' from this quote.")
    }
    func testStripsModelTokensButPreservesNonLatinText() {
        XCTAssertEqual(Transcript.clean("<|startoftranscript|>  سلام   دنیا <|endoftext|>"), "سلام دنیا")
    }
    func testReleaseDuringPermissionPromptPreventsRecording() {
        var gate = HoldGate()
        let token = gate.press()
        gate.release()
        XCTAssertFalse(gate.mayStart(token))
        let next = gate.press()
        XCTAssertFalse(gate.mayStart(token))
        XCTAssertTrue(gate.mayStart(next))
    }
}
