//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if MOCKING
enum MockSupport {
    static func mock<Output>(for type: Output.Type) -> Output? {
        guard let mockable = type as? any Mockable.Type else { return nil }
        return mockable.mock(as: Output.self) as? Output
    }
}
#endif
