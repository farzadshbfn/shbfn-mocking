//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

// assertMacro over prebuilt SwiftSyntaxMacrosGenericTestSupport; keeps macro tests off a swift-syntax source build.
#if os(macOS) || os(Linux)
import MockingMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosGenericTestSupport
import Testing

// The Mocking macros, by spelling, for assertMacroExpansion.
let mockingMacroSpecs: [String: MacroSpec] = [
    "Mockable": MacroSpec(type: MockableMacro.self, conformances: ["Mockable"]),
    "MockedMethod": MacroSpec(type: MockedMethodMacro.self),
    "MockedProperty": MacroSpec(type: MockedPropertyMacro.self),
]

// Mirrors MacroTesting's assertMacro call shape so the test bodies read the same.
func assertMacro(
    _ macros: [String: Macro.Type]? = nil,
    of originalSource: () throws -> String,
    diagnostics: [DiagnosticSpec] = [],
    expansion expandedSource: (() -> String)? = nil,
    fixedSource: (() -> String)? = nil,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) rethrows {
    let original = try originalSource()
    let specs = macros?.mapValues { MacroSpec(type: $0) } ?? mockingMacroSpecs
    assertMacroExpansion(
        original,
        expandedSource: expandedSource?() ?? original,
        diagnostics: diagnostics,
        macroSpecs: specs,
        fixedSource: fixedSource?(),
        failureHandler: { Issue.record(Comment(rawValue: $0.message), sourceLocation: sourceLocation) }
    )
}
#endif
