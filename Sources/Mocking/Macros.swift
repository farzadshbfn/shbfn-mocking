//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

@attached(extension, conformances: Mockable, names: arbitrary)
@attached(peer, names: suffixed(Mock))
public macro Mockable() = #externalMacro(module: "MockingMacros", type: "MockableMacro")

#if MOCKING
@attached(peer, names: prefixed(`$`))
@attached(body)
public macro MockedMethod() = #externalMacro(module: "MockingMacros", type: "MockedMethodMacro")

/// Selects the mock runtime used by `@MockedProperty`.
public enum MockedPropertyKind {
    case get
    case getSet
    case getAsync
    case getAsyncSet
    case throwingGet(Error.Type?)
    case throwingGetSet(Error.Type?)
}

public extension MockedPropertyKind {
    static var getThrows: Self { .throwingGet(nil) }
    static var getThrowsSet: Self { .throwingGetSet(nil) }

    static func getThrows(_ failure: Error.Type) -> Self { .throwingGet(failure) }
    static func getThrowsSet(_ failure: Error.Type) -> Self { .throwingGetSet(failure) }
}

@attached(peer, names: prefixed(`$`))
@attached(accessor)
public macro MockedProperty(_ kind: MockedPropertyKind? = nil) =
    #externalMacro(module: "MockingMacros", type: "MockedPropertyMacro")
#endif
