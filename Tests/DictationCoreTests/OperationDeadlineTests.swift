import XCTest
@testable import DictationCore

final class OperationDeadlineTests: XCTestCase {
    func testCompletedValue() async throws {
        let result = try await OperationDeadline.run(seconds: 1) { 42 }
        guard case .value(let value) = result else { return XCTFail("Unexpected timeout") }
        XCTAssertEqual(value, 42)
    }
    func testDoesNotWaitForUncooperativeOperationOrAcceptLateResult() async throws {
        let start = ProcessInfo.processInfo.systemUptime
        let result = try await OperationDeadline.run(seconds: 0.03) {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.8) { continuation.resume(returning: 42) }
            }
        }
        guard case .timedOut = result else { return XCTFail("Late result won") }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 0.6)
        // Let the ignored operation finish: a second resume would trap here.
        try await Task.sleep(for: .seconds(0.9))
    }
    func testParentCancellationReturnsPromptly() async throws {
        let task = Task {
            try await OperationDeadline.run(seconds: 10) {
                await withCheckedContinuation { continuation in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { continuation.resume(returning: 1) }
                }
            }
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation was ignored") }
        catch is CancellationError { }
    }
    func testOperationErrorIsPreserved() async throws {
        struct Failure: Error {}
        do {
            let _: DeadlineResult<Int> = try await OperationDeadline.run(seconds: 1) { throw Failure() }
            XCTFail("Error was lost")
        } catch is Failure { }
    }
}
