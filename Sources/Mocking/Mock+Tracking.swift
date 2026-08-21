//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if MOCKING
import Foundation
import Synchronization

/// Call-tracking surface shared by mock methods and property accessors.
public protocol CallTrackable: AnyObject, Sendable {
    associatedtype CallInput
    var tracker: CallTracker<CallInput> { get }
}

extension CallTrackable {
    public var callCount: Int { tracker.count }

    public func waitForCall(count: Int = 1, deadline: Duration = .seconds(1)) async throws {
        try await tracker.waitForCall(count: count, deadline: deadline)
    }

    /// Arguments from the most recent recorded call.
    public var args: CallInput? { tracker.lastInput }

    /// Every recorded call's arguments, in order.
    public var history: [CallInput] { tracker.inputHistory }
}

extension CallTrackable where CallInput == Void {
    public var args: Void? { callCount > 0 ? () : nil }
    public var history: [Void] { Array(repeating: (), count: callCount) }
}

/// Thrown when `waitForCall` is not satisfied before the deadline.
public struct MockWaitError: Error, Equatable, CustomStringConvertible {
    public let subject: String?
    public let requiredCount: Int
    public let actualCount: Int
    public let deadline: Duration

    public init(
        subject: String? = nil,
        requiredCount: Int,
        actualCount: Int,
        deadline: Duration
    ) {
        self.subject = subject
        self.requiredCount = requiredCount
        self.actualCount = actualCount
        self.deadline = deadline
    }

    public var description: String {
        if let subject {
            return
                "Timed out after \(deadline) waiting for '\(subject)' "
                + "(required \(requiredCount) calls, got \(actualCount))."
        }
        return
            "Timed out after \(deadline) waiting for call count \(requiredCount); "
            + "actual count was \(actualCount)."
    }
}

extension MockWaitError: LocalizedError {
    public var errorDescription: String? { description }
}

public final class CallTracker<Inputs>: @unchecked Sendable {
    private struct State: @unchecked Sendable {
        var count = 0
        var lastInput: Inputs?
        var inputHistory: [Inputs] = []
    }

    public var count: Int {
        state.withLock { $0.count }
    }

    public var lastInput: Inputs? {
        state.withLock { $0.lastInput }
    }

    public var inputHistory: [Inputs] {
        state.withLock { $0.inputHistory }
    }

    private let subject: String?
    private let state = Mutex(State())
    private let waiter = CallWaiter()

    public init(subject: String? = nil) {
        self.subject = subject
    }

    public func record(_ inputs: Inputs) {
        let newCount = state.withLock { state -> Int in
            state.count += 1
            state.lastInput = inputs
            state.inputHistory.append(inputs)
            return state.count
        }
        waiter.signal(currentCount: newCount)
    }

    public func waitForCall(count: Int = 1, deadline: Duration = .seconds(1)) async throws {
        try await waiter.waitUntil(
            subject: subject,
            requiredCount: count,
            deadline: deadline
        ) { self.count }
    }
}

extension CallTracker where Inputs == Void {
    public func record() {
        let newCount = state.withLock { state -> Int in
            state.count += 1
            return state.count
        }
        waiter.signal(currentCount: newCount)
    }
}

final class CallWaiter: Sendable {
    private struct PendingWait: Sendable {
        let id: UUID
        let requiredCount: Int
        let continuation: CheckedContinuation<Void, Error>
    }

    private let state = Mutex<[PendingWait]>([])

    func signal(currentCount: Int) {
        let resumed = state.withLock { pending -> [CheckedContinuation<Void, Error>] in
            var continuations: [CheckedContinuation<Void, Error>] = []
            pending.removeAll { wait in
                guard currentCount >= wait.requiredCount else { return false }
                continuations.append(wait.continuation)
                return true
            }
            return continuations
        }
        for continuation in resumed {
            continuation.resume()
        }
    }

    func waitUntil(
        subject: String?,
        requiredCount: Int,
        deadline: Duration,
        currentCount: @Sendable @escaping () -> Int
    ) async throws {
        if currentCount() >= requiredCount {
            return
        }

        let waitID = UUID()
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        self.enqueue(
                            id: waitID,
                            requiredCount: requiredCount,
                            currentCount: currentCount,
                            continuation: continuation
                        )
                    }
                } onCancel: {
                    self.cancel(id: waitID)
                }
            }
            group.addTask {
                try await Task.sleep(for: deadline)
                throw MockWaitError(
                    subject: subject,
                    requiredCount: requiredCount,
                    actualCount: currentCount(),
                    deadline: deadline
                )
            }

            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }

    private func enqueue(
        id: UUID,
        requiredCount: Int,
        currentCount: @Sendable @escaping () -> Int,
        continuation: CheckedContinuation<Void, Error>
    ) {
        let resumedImmediately = state.withLock { pending -> Bool in
            if currentCount() >= requiredCount {
                return true
            }
            pending.append(PendingWait(id: id, requiredCount: requiredCount, continuation: continuation))
            return false
        }
        if resumedImmediately {
            continuation.resume()
        }
    }

    private func cancel(id: UUID) {
        let continuation = state.withLock { pending -> CheckedContinuation<Void, Error>? in
            guard let index = pending.firstIndex(where: { $0.id == id }) else { return nil }
            return pending.remove(at: index).continuation
        }
        continuation?.resume(throwing: CancellationError())
    }
}
#endif
