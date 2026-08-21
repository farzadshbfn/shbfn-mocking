//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if MOCKING
extension Mock {
    package enum Configuration<Closure: ClosureSignature> {
        case unset
        case returns(Closure.Output)
        case failure(Closure.Failure)
        case onCall(Closure)

        package typealias Inputs = Closure.Inputs
        package typealias Output = Closure.Output
        package typealias Failure = Closure.Failure
    }
}

extension Mock.Configuration {
    mutating func setPlainOnCall<Inputs, Output>(
        _ handler: ((Inputs) -> Output)?
    ) where Closure == SyncClosure<Inputs, Output, Never> {
        if let handler {
            var closure = SyncClosure<Inputs, Output, Never>()
            closure.plainHandler = handler
            closure.handler = handler
            self = .onCall(closure)
        } else if case .onCall = self {
            self = .unset
        }
    }

    func plainOnCall<Inputs, Output>() -> ((Inputs) -> Output)? where Closure == SyncClosure<Inputs, Output, Never> {
        if case .onCall(let closure) = self {
            return closure.plainHandler
        }
        return nil
    }

    mutating func setPlainOnCall<Inputs, Output>(
        _ handler: ((Inputs) async -> Output)?
    ) where Closure == AsyncClosure<Inputs, Output, Never> {
        if let handler {
            var closure = AsyncClosure<Inputs, Output, Never>()
            closure.plainHandler = handler
            closure.handler = handler
            self = .onCall(closure)
        } else if case .onCall = self {
            self = .unset
        }
    }

    func plainOnCall<Inputs, Output>() -> ((Inputs) async -> Output)?
    where Closure == AsyncClosure<Inputs, Output, Never> {
        if case .onCall(let closure) = self {
            return closure.plainHandler
        }
        return nil
    }
}
#endif
