//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

/// Types that can provide a deterministic default value for lenient mocks.
public protocol Mockable {
    #if MOCKING
    static var mock: Self { get }

    /// Type-erased witness used to resolve `mock` across module boundaries.
    static func mock(as outputType: Any.Type) -> Any?
    #endif
}

#if MOCKING
extension Mockable {
    public static func mock(as outputType: Any.Type) -> Any? {
        guard outputType == Self.self else { return nil }
        return mock
    }
}

extension Int: Mockable { public static var mock: Int { 0 } }
extension Int8: Mockable { public static var mock: Int8 { 0 } }
extension Int16: Mockable { public static var mock: Int16 { 0 } }
extension Int32: Mockable { public static var mock: Int32 { 0 } }
extension Int64: Mockable { public static var mock: Int64 { 0 } }
extension UInt: Mockable { public static var mock: UInt { 0 } }
extension UInt8: Mockable { public static var mock: UInt8 { 0 } }
extension UInt16: Mockable { public static var mock: UInt16 { 0 } }
extension UInt32: Mockable { public static var mock: UInt32 { 0 } }
extension UInt64: Mockable { public static var mock: UInt64 { 0 } }
extension Float: Mockable { public static var mock: Float { 0 } }
extension Double: Mockable { public static var mock: Double { 0 } }
extension Bool: Mockable { public static var mock: Bool { false } }
extension String: Mockable { public static var mock: String { "" } }

extension Optional: Mockable {
    public static var mock: Wrapped? { nil }
}
#endif
