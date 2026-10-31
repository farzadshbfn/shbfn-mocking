//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

@attached(extension, conformances: Mockable, names: arbitrary)
@attached(peer, names: suffixed(Mock))
public macro Mockable() = #externalMacro(module: "MockingMacros", type: "MockableMacro")

#if DEBUG || MOCKING
/// `named:` overrides the generated peer name, so `@MockedMethod(named: "run2")` gives `$run2`.
/// The name must be a string literal, because the macro reads it at compile time.
@attached(peer, names: prefixed(`$`), arbitrary)
@attached(body)
public macro MockedMethod(named: String? = nil) =
    #externalMacro(module: "MockingMacros", type: "MockedMethodMacro")

/// Selects the mock runtime used by `@MockedProperty`.
public enum MockedPropertyKind {
    case get
    case getSet
    case getAsync
    case getAsyncSet
    case getThrows(Error.Type?)
    case getThrowsSet(Error.Type?)
    case getAsyncThrows(Error.Type?)
}

/// A throwing kind reads with or without a failure type: `.getThrows` or `.getThrows(MyError.self)`.
public extension MockedPropertyKind {
    static var getThrows: Self { .getThrows(nil) }
    static var getThrowsSet: Self { .getThrowsSet(nil) }
    static var getAsyncThrows: Self { .getAsyncThrows(nil) }
}

/// `named:` overrides the generated peer name, so `@MockedProperty(named: "x", .get)` gives `$x`.
@attached(peer, names: prefixed(`$`), arbitrary)
@attached(accessor)
public macro MockedProperty(named: String? = nil, _ kind: MockedPropertyKind? = nil) =
    #externalMacro(module: "MockingMacros", type: "MockedPropertyMacro")
#endif
