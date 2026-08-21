//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

/// Marker protocol for inline mutation via `with`; a copy of Core's `Withable` so Mocking needs no Core dependency.
public protocol MockWithable: ~Copyable {}

// Every method is @_disfavoredOverload so a same-shaped `with` from another conformance wins over this one.
extension MockWithable where Self: ~Copyable {
    @_disfavoredOverload
    public consuming func with(_ body: (inout Self) -> Void) -> Self {
        var value = consume self
        body(&value)
        return value
    }

    @_disfavoredOverload
    public consuming func with(_ body: (inout Self) async -> Void) async -> Self {
        var value = consume self
        await body(&value)
        return value
    }
}

extension MockWithable where Self: ~Copyable, Self: Sendable {
    @_disfavoredOverload
    public consuming func with(_ body: (inout sending Self) -> Void) -> sending Self {
        var value = consume self
        body(&value)
        return value
    }

    @_disfavoredOverload
    public consuming func with(_ body: (inout sending Self) async -> Void) async -> sending Self {
        var value = consume self
        await body(&value)
        return value
    }
}

extension MockWithable where Self: Escapable, Self: Copyable {
    @_disfavoredOverload
    @discardableResult
    public borrowing func with(_ body: (inout Self) -> Void) -> Self {
        var copy = copy self
        body(&copy)
        return copy
    }

    @_disfavoredOverload
    @discardableResult
    public borrowing func with(_ body: (inout Self) async -> Void) async -> Self {
        var copy = copy self
        await body(&copy)
        return copy
    }
}
