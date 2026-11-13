//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if Dependencies
@_exported import Dependencies

/// `@Mockable`, plus a `<Name>Key` whose test value is an exclusive mock: an unset call reports a test issue.
/// Read it as `@Dependency(Authorization.TokenManagerKey.self)`, or write a `DependencyValues` accessor.
/// Give the key a live value with `extension Authorization.TokenManagerKey: DependencyKey`.
@attached(extension, conformances: Mockable, names: arbitrary)
@attached(peer, names: suffixed(Mock), suffixed(Key))
public macro MockableDependency() =
    #externalMacro(module: "MockingMacros", type: "MockableDependencyMacro")
#endif
