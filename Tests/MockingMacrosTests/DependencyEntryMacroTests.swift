//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct `DependencyEntry Macro` {
    @Test func `an existential reads the protocol's Key alias`() {
        assertMacro {
            """
            extension DependencyValues {
                @DependencyEntry public var authorizationTokenManager: any Authorization.TokenManager
            }
            """
        } expansion: {
            """
            extension DependencyValues {
                public var authorizationTokenManager: any Authorization.TokenManager {
                    get {
                        self[Authorization.TokenManager.Key.self]
                    }
                    set {
                        self[Authorization.TokenManager.Key.self] = newValue
                    }
                }
            }
            """
        }
    }

    @Test func `a struct reads its Key alias`() {
        assertMacro {
            """
            extension DependencyValues {
                @DependencyEntry var weeklyPlanClient: WeeklyPlanClient
            }
            """
        } expansion: {
            """
            extension DependencyValues {
                var weeklyPlanClient: WeeklyPlanClient {
                    get {
                        self[WeeklyPlanClient.Key.self]
                    }
                    set {
                        self[WeeklyPlanClient.Key.self] = newValue
                    }
                }
            }
            """
        }
    }

    @Test func `an explicit key wins over the type`() {
        assertMacro {
            """
            extension DependencyValues {
                @DependencyEntry(Clocks.ContinuousKey.self) var clock: any Clock<Duration>
            }
            """
        } expansion: {
            """
            extension DependencyValues {
                var clock: any Clock<Duration> {
                    get {
                        self[Clocks.ContinuousKey.self]
                    }
                    set {
                        self[Clocks.ContinuousKey.self] = newValue
                    }
                }
            }
            """
        }
    }

    @Test func `a property with an initial value is rejected`() {
        assertMacro(
            of: {
                """
                extension DependencyValues {
                    @DependencyEntry var greeting: String = "hi"
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: """
                    @DependencyEntry requires one 'var' with a type annotation, no initial value, and no accessors.
                    """,
                    line: 2,
                    column: 5
                ),
            ],
            expansion: {
                """
                extension DependencyValues {
                    var greeting: String = "hi"
                }
                """
            }
        )
    }
}
#endif
