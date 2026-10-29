import Foundation

public enum DeadlineResult<Value: Sendable>: Sendable {
    case value(Value)
    case timedOut
}

/// Returns promptly even if an underlying API takes time to honor cancellation.
/// A late result can never resume the caller twice or replace its chosen result.
public enum OperationDeadline {
    public static func run<Value: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> Value) async throws -> DeadlineResult<Value> {
        let race = DeadlineRace<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.attach(continuation)
                let worker = Task {
                    do {
                        try Task.checkCancellation()
                        let value = try await operation()
                        race.complete(.success(.value(value)))
                    } catch { race.complete(.failure(error)) }
                }
                let timer = Task {
                    do {
                        try await Task.sleep(for: .seconds(max(0, seconds)))
                        race.complete(.success(.timedOut))
                    } catch { /* Another outcome cancelled this timer. */ }
                }
                race.attach([worker, timer])
            }
        } onCancel: { race.complete(.failure(CancellationError())) }
    }
}

private final class DeadlineRace<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<DeadlineResult<Value>, Error>?
    private var continuation: CheckedContinuation<DeadlineResult<Value>, Error>?
    private var tasks: [Task<Void, Never>] = []

    func attach(_ continuation: CheckedContinuation<DeadlineResult<Value>, Error>) {
        lock.lock()
        if let result { lock.unlock(); continuation.resume(with: result) }
        else { self.continuation = continuation; lock.unlock() }
    }
    func attach(_ tasks: [Task<Void, Never>]) {
        lock.lock()
        let finished = result != nil
        if !finished { self.tasks = tasks }
        lock.unlock()
        if finished { tasks.forEach { $0.cancel() } }
    }
    func complete(_ result: Result<DeadlineResult<Value>, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation, tasks = self.tasks
        self.continuation = nil; self.tasks = []
        lock.unlock()
        tasks.forEach { $0.cancel() }
        continuation?.resume(with: result)
    }
}
