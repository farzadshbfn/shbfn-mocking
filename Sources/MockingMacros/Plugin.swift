//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MockingMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = {
        var macros: [Macro.Type] = [MockableMacro.self]
        #if DEBUG || MOCKING
        macros.append(contentsOf: [MockedMethodMacro.self, MockedPropertyMacro.self])
        #endif
        return macros
    }()
}
