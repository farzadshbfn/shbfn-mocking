//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if DEBUG || MOCKING
public enum Mock {
    public enum Method<Inputs, Output> {
        public typealias Sync = SyncInvocation<Inputs, Output, Never>
        public typealias Async = AsyncInvocation<Inputs, Output, Never>
        public typealias SyncThrows<Failure: Error> = SyncInvocation<Inputs, Output, Failure>
        public typealias AsyncThrows<Failure: Error> = AsyncInvocation<Inputs, Output, Failure>
    }

    public enum Property<Value> {
        public final class Get: @unchecked Sendable {
            public let get: SyncInvocation<Void, Value, Never>

            public init(subject: String? = nil) {
                self.get = SyncInvocation(subject: subject.map { "\($0).get" })
            }
        }

        public final class GetSet: @unchecked Sendable {
            public let get: SyncInvocation<Void, Value, Never>
            public let set: SyncInvocation<Value, Void, Never>

            public init(subject: String? = nil) {
                self.get = SyncInvocation(subject: subject.map { "\($0).get" })
                self.set = SyncInvocation(subject: subject.map { "\($0).set" })
            }
        }

        public final class GetAsync: @unchecked Sendable {
            public let get: AsyncInvocation<Void, Value, Never>

            public init(subject: String? = nil) {
                self.get = AsyncInvocation(subject: subject.map { "\($0).get" })
            }
        }

        public final class GetAsyncSet: @unchecked Sendable {
            public let get: AsyncInvocation<Void, Value, Never>
            public let set: SyncInvocation<Value, Void, Never>

            public init(subject: String? = nil) {
                self.get = AsyncInvocation(subject: subject.map { "\($0).get" })
                self.set = SyncInvocation(subject: subject.map { "\($0).set" })
            }
        }

        /// Swift forbids `set` beside a `get` that is `async` or `throws`, so this kind has no setter.
        public final class GetAsyncThrows<Failure: Error>: @unchecked Sendable {
            public let get: AsyncInvocation<Void, Value, Failure>

            public init(subject: String? = nil) {
                self.get = AsyncInvocation(subject: subject.map { "\($0).get" })
            }
        }

        public final class GetThrows<Failure: Error>: @unchecked Sendable {
            public let get: SyncInvocation<Void, Value, Failure>

            public init(subject: String? = nil) {
                self.get = SyncInvocation(subject: subject.map { "\($0).get" })
            }
        }

        public final class GetThrowsSet<Failure: Error>: @unchecked Sendable {
            public let get: SyncInvocation<Void, Value, Failure>
            public let set: SyncInvocation<Value, Void, Never>

            public init(subject: String? = nil) {
                self.get = SyncInvocation(subject: subject.map { "\($0).get" })
                self.set = SyncInvocation(subject: subject.map { "\($0).set" })
            }
        }
    }
}
#endif
