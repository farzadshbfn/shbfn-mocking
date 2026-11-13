//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if Dependencies
@_exported import Dependencies

/// `@Mockable`, plus a `<Name>Key` whose test value is an exclusive mock: an unset call reports a test issue.
/// The protocol gets `typealias Key`, so `@DependencyEntry` can find it.
/// Give the key a live value with `extension Authorization.TokenManagerKey: DependencyKey`.
@attached(extension, conformances: Mockable, names: arbitrary)
@attached(peer, names: suffixed(Mock), suffixed(Key))
public macro MockableDependency() =
    #externalMacro(module: "MockingMacros", type: "MockableDependencyMacro")

/// Writes the `get` and `set` of a `DependencyValues` property, so call sites keep the key path.
/// `any Authorization.TokenManager` reads `Authorization.TokenManager.Key`; any other type is its own key.
@attached(accessor, names: named(get), named(set))
public macro DependencyEntry() =
    #externalMacro(module: "MockingMacros", type: "DependencyEntryMacro")

/// Names the key, for a property whose type does not lead to it.
@attached(accessor, names: named(get), named(set))
public macro DependencyEntry<Key: TestDependencyKey>(_ key: Key.Type) =
    #externalMacro(module: "MockingMacros", type: "DependencyEntryMacro")
#endif
