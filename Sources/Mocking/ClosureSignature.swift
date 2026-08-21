//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if MOCKING
public protocol ClosureSignature {
    associatedtype Inputs
    associatedtype Output
    associatedtype Failure: Error = Never
}

public protocol SyncInvokable: ClosureSignature {
    func callAsFunction(_ inputs: Inputs) throws(Failure) -> Output!
}

public protocol AsyncInvokable: ClosureSignature {
    func callAsFunction(_ inputs: Inputs) async throws(Failure) -> Output!
}

public struct SyncClosure<Inputs, Output, Failure: Error> {
    public var handler: ((Inputs) throws(Failure) -> Output)?
    public var plainHandler: ((Inputs) -> Output)?

    public init() {}

    public func callAsFunction(_ inputs: Inputs) throws(Failure) -> Output! {
        try handler?(inputs)
    }
}

public struct AsyncClosure<Inputs, Output, Failure: Error> {
    public var handler: ((Inputs) async throws(Failure) -> Output)?
    public var plainHandler: ((Inputs) async -> Output)?

    public init() {}

    public func callAsFunction(_ inputs: Inputs) async throws(Failure) -> Output! {
        try await handler?(inputs)
    }
}

extension SyncClosure: ClosureSignature, SyncInvokable { }

extension AsyncClosure: ClosureSignature, AsyncInvokable { }
#endif
