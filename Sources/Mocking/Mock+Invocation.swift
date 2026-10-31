//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if DEBUG || MOCKING
import Synchronization

// MARK: - Types

extension Mock {
    public class Invocation<Closure: ClosureSignature>: @unchecked Sendable, CallTrackable {
        public typealias CallInput = Closure.Inputs

        public let tracker: CallTracker<Closure.Inputs>
        fileprivate let configurationLock = Mutex(Configuration<Closure>.unset)
        public var isExclusive = false

        public init(subject: String? = nil) {
            self.tracker = CallTracker(subject: subject)
        }

        fileprivate func updateConfiguration(_ transform: (inout Configuration<Closure>) -> Void) {
            configurationLock.withLock { transform(&$0) }
        }
    }

    public final class SyncInvocation<Inputs, Output, Failure: Error>:
        Invocation<SyncClosure<Inputs, Output, Failure>>, @unchecked Sendable {}

    public final class AsyncInvocation<Inputs, Output, Failure: Error>:
        Invocation<AsyncClosure<Inputs, Output, Failure>>, @unchecked Sendable {}
}

// MARK: - Configuration

extension Mock.Invocation {
    public var returns: Closure.Output? {
        get {
            if case .returns(let value) = configurationLock.withLock({ $0 }) {
                return value
            }
            return nil
        }
        set {
            updateConfiguration {
                if let newValue {
                    $0 = .returns(newValue)
                } else if case .returns = $0 {
                    $0 = .unset
                }
            }
        }
    }

    public var `throws`: Closure.Failure? {
        get {
            if case .failure(let failure) = configurationLock.withLock({ $0 }) {
                return failure
            }
            return nil
        }
        set {
            updateConfiguration {
                if let newValue {
                    $0 = .failure(newValue)
                } else if case .failure = $0 {
                    $0 = .unset
                }
            }
        }
    }
}

// MARK: - onCall

extension Mock.SyncInvocation where Failure == Never {
    public var onCall: ((Inputs) -> Output)? {
        get { configurationLock.withLock { $0.plainOnCall() } }
        set { updateConfiguration { $0.setPlainOnCall(newValue) } }
    }
}

extension Mock.AsyncInvocation where Failure == Never {
    public var onCall: ((Inputs) async -> Output)? {
        get { configurationLock.withLock { $0.plainOnCall() } }
        set { updateConfiguration { $0.setPlainOnCall(newValue) } }
    }
}

extension Mock.SyncInvocation {
    public var onCall: ((Inputs) throws(Failure) -> Output)? {
        get {
            if case .onCall(let closure) = configurationLock.withLock({ $0 }) {
                return closure.handler
            }
            return nil
        }
        set {
            updateConfiguration {
                if let newValue {
                    var closure = SyncClosure<Inputs, Output, Failure>()
                    closure.handler = newValue
                    $0 = .onCall(closure)
                } else if case .onCall = $0 {
                    $0 = .unset
                }
            }
        }
    }
}

extension Mock.AsyncInvocation {
    public var onCall: ((Inputs) async throws(Failure) -> Output)? {
        get {
            if case .onCall(let closure) = configurationLock.withLock({ $0 }) {
                return closure.handler
            }
            return nil
        }
        set {
            updateConfiguration {
                if let newValue {
                    var closure = AsyncClosure<Inputs, Output, Failure>()
                    closure.handler = newValue
                    $0 = .onCall(closure)
                } else if case .onCall = $0 {
                    $0 = .unset
                }
            }
        }
    }
}

// MARK: - result (sync)

extension Mock.Invocation where Closure: SyncInvokable {
    public func result(
        _ inputs: Closure.Inputs,
        file: StaticString = #file,
        line: UInt = #line
    ) throws(Closure.Failure) -> Closure.Output {
        defer { tracker.record(inputs) }
        switch configurationLock.withLock({ $0 }) {
        case .failure(let failure):
            throw failure
        case .onCall(let closure):
            return try closure(inputs)
        case .returns(let value):
            return value
        case .unset:
            if !isExclusive, let mock = MockSupport.mock(for: Closure.Output.self) {
                return mock
            }
            fatalError("Mock return value not configured.", file: file, line: line)
        }
    }
}

extension Mock.SyncInvocation where Inputs == Void {
    public func result(
        file: StaticString = #file,
        line: UInt = #line
    ) throws(Failure) -> Output {
        try result((), file: file, line: line)
    }
}

extension Mock.SyncInvocation where Output == Void {
    public func result(
        _ inputs: Inputs,
        file: StaticString = #file,
        line: UInt = #line
    ) throws(Failure) {
        defer { tracker.record(inputs) }
        switch configurationLock.withLock({ $0 }) {
        case .failure(let failure):
            throw failure
        case .onCall(let closure):
            _ = try closure(inputs)
        case .returns:
            return
        case .unset:
            if isExclusive {
                fatalError("Mock setter not configured.", file: file, line: line)
            }
        }
    }
}

// MARK: - result (async)

extension Mock.Invocation where Closure: AsyncInvokable {
    public func result(
        _ inputs: Closure.Inputs,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws(Closure.Failure) -> Closure.Output {
        defer { tracker.record(inputs) }
        switch configurationLock.withLock({ $0 }) {
        case .failure(let failure):
            throw failure
        case .onCall(let closure):
            return try await closure(inputs)
        case .returns(let value):
            return value
        case .unset:
            if !isExclusive, let mock = MockSupport.mock(for: Closure.Output.self) {
                return mock
            }
            fatalError("Mock return value not configured.", file: file, line: line)
        }
    }
}

extension Mock.AsyncInvocation where Inputs == Void {
    public func result(
        file: StaticString = #file,
        line: UInt = #line
    ) async throws(Failure) -> Output {
        try await result((), file: file, line: line)
    }
}

extension Mock.AsyncInvocation where Output == Void {
    public func result(
        _ inputs: Inputs,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws(Failure) {
        defer { tracker.record(inputs) }
        switch configurationLock.withLock({ $0 }) {
        case .failure(let failure):
            throw failure
        case .onCall(let closure):
            _ = try await closure(inputs)
        case .returns:
            return
        case .unset:
            if isExclusive {
                fatalError("Mock return value not configured.", file: file, line: line)
            }
        }
    }
}
#endif
