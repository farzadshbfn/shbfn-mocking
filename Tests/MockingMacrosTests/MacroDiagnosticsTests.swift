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

    @Test func overloadedMethodDiagnoses() {
        assertMacro(
            of: {
                """
                @Mockable
                protocol VoidWorker {
                    func run()
                    func run(force: Bool)
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: """
                    @Mockable cannot mock two members named 'run'. Both would declare the peer \
                    '$run'. Give one of them its own peer name with 'named:'. Keep your own \
                    declaration as it is.
                    """,
                    line: 4,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add @MockedMethod(named: \"runForce\")")]
                ),
            ],
            expansion: {
                """
                protocol VoidWorker {
                    func run()
                    func run(force: Bool)
                }
                """
            },
            fixedSource: {
                """
                @Mockable
                protocol VoidWorker {
                    func run()
                    @MockedMethod(named: "runForce")
                    func run(force: Bool)
                }
                """
            }
        )
    }

    @Test func methodAndPropertySharingANameDiagnoses() {
        assertMacro(
            of: {
                """
                @Mockable
                protocol Runner {
                    var run: Bool { get }
                    func run()
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: """
                    @Mockable cannot mock two members named 'run'. Both would declare the peer \
                    '$run'. Give one of them its own peer name with 'named:'. Keep your own \
                    declaration as it is.
                    """,
                    line: 4,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add @MockedMethod(named: \"runPeer\")")]
                ),
            ],
            expansion: {
                """
                protocol Runner {
                    var run: Bool { get }
                    func run()
                }
                """
            },
            fixedSource: {
                """
                @Mockable
                protocol Runner {
                    var run: Bool { get }
                    @MockedMethod(named: "runPeer")
                    func run()
                }
                """
            }
        )
    }

    // `named:` moves a peer, so it can also create a collision. The check reads the effective name.
    @Test func namedThatCollidesDiagnoses() {
        assertMacro(
            of: {
                """
                @Mockable
                protocol Worker {
                    func run()
                    @MockedMethod(named: "run") func execute()
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: """
                    @Mockable cannot mock two members named 'run'. Both would declare the peer \
                    '$run'. Give one of them its own peer name with 'named:'. Keep your own \
                    declaration as it is.
                    """,
                    line: 4,
                    column: 5,
                    fixIts: [FixItSpec(message: "Add @MockedMethod(named: \"executePeer\")")]
                ),
            ],
            expansion: {
                """
                protocol Worker {
                    func run()
                    func execute()
                }
                """
            }
        )
    }

    @Test func nonLiteralPeerNameDiagnoses() {
        assertMacro(
            of: {
                """
                struct Service {
                    @MockedMethod(named: externalName) func load() -> Int
                }
                """
            },
            // The peer and body roles of @MockedMethod each read the name, so the error fires twice.
            diagnostics: [
                DiagnosticSpec(
                    message: "'named' must be a string literal, not 'externalName'.",
                    line: 2,
                    column: 5
                ),
                DiagnosticSpec(
                    message: "'named' must be a string literal, not 'externalName'.",
                    line: 2,
                    column: 5
                ),
            ],
            expansion: {
                """
                struct Service {
                    func load() -> Int
                }
                """
            }
        )
    }

    @Test func peerNameThatIsNotAnIdentifierDiagnoses() {
        assertMacro(
            of: {
                """
                struct Service {
                    @MockedProperty(named: "not valid", .get) var label: String
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: "'named' must be a Swift identifier, because the peer becomes '$not valid'.",
                    line: 2,
                    column: 5
                ),
                DiagnosticSpec(
                    message: "'named' must be a Swift identifier, because the peer becomes '$not valid'.",
                    line: 2,
                    column: 5
                ),
            ],
            expansion: {
                """
                struct Service {
                    var label: String
                }
                """
            }
        )
    }

    @Test func mockedAttributeOnStructMemberDiagnoses() {
        assertMacro(
            of: {
                """
                @Mockable
                struct Store {
                    @MockedProperty(named: "tokenTwo") var token: () async -> String
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: """
                    @Mockable does not support @MockedMethod or @MockedProperty on the struct member \
                    'token'. Remove the attribute. Two stored properties cannot share a name, so their \
                    peers never collide.
                    """,
                    line: 1,
                    column: 1
                ),
            ],
            // @Mockable emits nothing, but the member's own @MockedProperty still makes its peer.
            expansion: {
                """
                struct Store {
                    var token: () async -> String {
                        get {
                            return $tokenTwo.get.result()
                        }
                        set {
                            $tokenTwo.set.result(newValue)
                        }
                    }

                    #if MOCKING
                    nonisolated let $tokenTwo = Mocking.Mock.Property<() async -> String>.GetSet(subject: "token")
                    #endif
                }
                """
            }
        )
    }
}
#endif
