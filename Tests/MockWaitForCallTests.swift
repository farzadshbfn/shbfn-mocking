//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import Foundation
import Mocking
import Testing

@Suite
struct `Mock.WaitForCall` {
    @Test
    func `waitForCall resumes after the expected number of calls`() async throws {
        let mock = Mock.Method<Void, Int>.Sync()

        Task {
            try? await Task.sleep(for: .milliseconds(25))
            _ = mock.result()
        }

        try await mock.waitForCall()
        #expect(mock.callCount == 1)
    }

    @Test
    func `waitForCall resumes only after result completes`() async throws {
        let mock = Mock.Method<Void, Int>.Sync()
        let didFinish = CompletionFlag()
        mock.onCall = { _ in
            Thread.sleep(forTimeInterval: 0.05)
            didFinish.markFinished()
            return 0
        }

        Task {
            _ = mock.result()
        }

        try await mock.waitForCall()
        #expect(didFinish.isFinished)
        #expect(mock.callCount == 1)
    }

    @Test
    func `call is not recorded while result is in progress`() async throws {
        let mock = Mock.Method<Void, Int>.Sync()
        let gate = DispatchSemaphore(value: 0)
        mock.onCall = { _ in
            gate.wait()
            return 0
        }

        let callTask = Task {
            _ = mock.result()
        }
        try await Task.sleep(for: .milliseconds(10))
        #expect(mock.callCount == 0)

        gate.signal()
        _ = await callTask.value
        #expect(mock.callCount == 1)
    }

    @Test
    func `waitForCall resumes only after async result completes`() async throws {
        let mock = Mock.Method<Void, Int>.Async()
        let didFinish = CompletionFlag()
        let gate = AsyncGate()
        mock.onCall = { _ in
            await gate.wait()
            didFinish.markFinished()
            return 0
        }

        Task {
            await mock.result()
        }
        try await Task.sleep(for: .milliseconds(10))
        #expect(mock.callCount == 0)

        let waitTask = Task {
            try await mock.waitForCall()
        }
        await gate.open()
        try await waitTask.value
        #expect(didFinish.isFinished)
        #expect(mock.callCount == 1)
    }

    @Test
    func `throwing result records call when error propagates`() {
        enum TestFailure: Error { case failed }

        let mock = Mock.Method<Void, Int>.SyncThrows<TestFailure>()
        mock.throws = .failed

        #expect(throws: TestFailure.failed) {
            try mock.result()
        }
        #expect(mock.callCount == 1)
    }

    @Test
    func `async throwing result records call when error propagates`() async {
        enum TestFailure: Error { case failed }

        let mock = Mock.Method<Void, Int>.AsyncThrows<TestFailure>()
        mock.throws = .failed

        await #expect(throws: TestFailure.failed) {
            try await mock.result()
        }
        #expect(mock.callCount == 1)
    }

    @Test
    func `waitForCall waits for a specific call count`() async throws {
        let mock = Mock.Method<Void, Int>.Sync()

        Task {
            try? await Task.sleep(for: .milliseconds(10))
            _ = mock.result()
            try? await Task.sleep(for: .milliseconds(10))
            _ = mock.result()
        }

        try await mock.waitForCall(count: 2)
        #expect(mock.callCount == 2)
    }

    @Test
    func `waitForCall throws when the deadline passes`() async {
        let mock = Mock.Method<Void, Int>.Sync()

        await #expect(throws: MockWaitError(requiredCount: 1, actualCount: 0, deadline: .milliseconds(50))) {
            try await mock.waitForCall(deadline: .milliseconds(50))
        }
    }

    @Test
    func `waitForCall error includes subject when configured`() async {
        let mock = Mock.Method<Void, Int>.Sync(subject: "configure()")

        await #expect(throws: MockWaitError(
            subject: "configure()",
            requiredCount: 1,
            actualCount: 0,
            deadline: .milliseconds(50)
        )) {
            try await mock.waitForCall(deadline: .milliseconds(50))
        }
    }

    @Test
    func `waitForCall resumes after property access`() async throws {
        let property = Mock.Property<String>.Get()

        Task {
            try? await Task.sleep(for: .milliseconds(25))
            _ = property.get.result()
        }

        try await property.get.waitForCall()
        #expect(property.get.callCount == 1)
    }

    @Test
    func `waitForCall resumes only after property get completes`() async throws {
        let property = Mock.Property<String>.Get()
        let didFinish = CompletionFlag()
        property.get.onCall = { _ in
            Thread.sleep(forTimeInterval: 0.05)
            didFinish.markFinished()
            return "ready"
        }

        Task {
            _ = property.get.result()
        }

        try await property.get.waitForCall()
        #expect(didFinish.isFinished)
        #expect(property.get.callCount == 1)
    }

    @Test
    func `waitForCall resumes only after property set completes`() async throws {
        let property = Mock.Property<Int>.GetSet()
        let didFinish = CompletionFlag()
        property.set.onCall = { _ in
            Thread.sleep(forTimeInterval: 0.05)
            didFinish.markFinished()
        }

        Task {
            property.set.result(1)
        }

        try await property.set.waitForCall()
        #expect(didFinish.isFinished)
        #expect(property.set.callCount == 1)
    }
}

private final class CompletionFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }

    func markFinished() {
        lock.lock()
        finished = true
        lock.unlock()
    }
}

private actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}
