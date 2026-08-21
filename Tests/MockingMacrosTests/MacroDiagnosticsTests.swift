//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import SwiftSyntaxMacrosGenericTestSupport
import Testing

// System-only: these use DiagnosticSpec and (unlike the expansion tests) do not compile under MacroTesting.
struct `Macro Diagnostics` {
    @Test func mockedMethodOnPropertyDiagnoses() {
        assertMacro(
            of: {
                """
                struct Service {
                    @MockedMethod var value: Int
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(message: "@MockedMethod can only be applied to functions.", line: 2, column: 5)
            ],
            expansion: {
                """
                struct Service {
                    var value: Int
                }
                """
            }
        )
    }

    @Test func mockedPropertyOnFunctionDiagnoses() {
        assertMacro(
            of: {
                """
                struct Service {
                    @MockedProperty func value() -> Int
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(message: "@MockedProperty can only be applied to properties.", line: 2, column: 5)
            ],
            expansion: {
                """
                struct Service {
                    func value() -> Int
                }
                """
            }
        )
    }

    @Test func mockableStructWithoutStoredPropertiesDiagnoses() {
        assertMacro(
            of: {
                """
                @Mockable
                struct Empty {}
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: "@Mockable requires at least one stored property on the struct.",
                    line: 1,
                    column: 1
                ),
            ],
            expansion: {
                """
                struct Empty {}
                """
            }
        )
    }

    @Test func witnessStructWithNestedMockTypeDiagnoses() {
        assertMacro(
            of: {
                """
                @Mockable
                struct Service {
                    struct Mock {}
                    var run: () -> Void
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: "@Mockable cannot synthesize a mock: 'Mock' is already declared. Rename the nested type.",
                    line: 1,
                    column: 1
                ),
            ],
            expansion: {
                """
                struct Service {
                    struct Mock {}
                    var run: () -> Void
                }
                """
            }
        )
    }

    @Test func staticRequirementInGenericProtocolDiagnoses() {
        assertMacro(
            of: {
                """
                @Mockable
                protocol Registry {
                    associatedtype Element
                    static func shared() -> Element
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: "@Mockable cannot mock static requirements on a protocol with associated types.",
                    line: 1,
                    column: 1
                ),
            ],
            expansion: {
                """
                protocol Registry {
                    associatedtype Element
                    static func shared() -> Element
                }
                """
            }
        )
    }

    @Test func witnessInoutClosureParameterDiagnoses() {
        assertMacro(
            of: {
                """
                @Mockable
                struct Service {
                    var mutate: (inout Int) -> Void
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: "@Mockable does not support 'inout' or variadic parameters in closure properties.",
                    line: 1,
                    column: 1
                ),
            ],
            expansion: {
                """
                struct Service {
                    var mutate: (inout Int) -> Void
                }
                """
            }
        )
    }

    @Test func unrecognizedPropertyKindDiagnoses() {
        assertMacro(
            of: {
                """
                struct Service {
                    @MockedProperty(.bogus) var value: Int
                }
                """
            },
            // The peer and accessor roles of @MockedProperty each parse the kind, so the error fires twice.
            diagnostics: [
                DiagnosticSpec(message: "Unrecognized @MockedProperty kind '.bogus'.", line: 2, column: 5),
                DiagnosticSpec(message: "Unrecognized @MockedProperty kind '.bogus'.", line: 2, column: 5),
            ],
            expansion: {
                """
                struct Service {
                    var value: Int
                }
                """
            }
        )
    }

    @Test func missingFailureTypeDiagnoses() {
        assertMacro(
            of: {
                """
                struct Service {
                    @MockedProperty(.getThrows()) var value: String
                }
                """
            },
            // The peer and accessor roles of @MockedProperty each parse the kind, so the error fires twice.
            diagnostics: [
                DiagnosticSpec(
                    message: "@MockedProperty(.getThrows) requires a failure type, e.g. .getThrows(MyError.self).",
                    line: 2,
                    column: 5
                ),
                DiagnosticSpec(
                    message: "@MockedProperty(.getThrows) requires a failure type, e.g. .getThrows(MyError.self).",
                    line: 2,
                    column: 5
                ),
            ],
            expansion: {
                """
                struct Service {
                    var value: String
                }
                """
            }
        )
    }
}
#endif
