//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if DEBUG || MOCKING
enum MockSupport {
    static func mock<Output>(for type: Output.Type) -> Output? {
        // `Void` cannot conform to `Mockable`, because it is a tuple type.
        // Its only value is the correct lenient default, so supply it here.
        if Output.self == Void.self { return () as? Output }
        guard let mockable = type as? any Mockable.Type else { return nil }
        return mockable.mock(as: Output.self) as? Output
    }
}
#endif
