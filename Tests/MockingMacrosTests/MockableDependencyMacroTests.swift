//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct `MockableDependency Macro` {
    @Test func `a nested protocol gets a key beside its mock, and the mock gets exclusive()`() {
        assertMacro {
            """
            extension Authorization {
                @MockableDependency
                public protocol TokenManager: Sendable {
                    var validToken: Token? { get async throws(Failure) }
                    func refresh(_ rejected: Token) async throws(Failure) -> Token
                }
            }
            """
        } expansion: {
            """
            extension Authorization {
                public protocol TokenManager: Sendable {
                    var validToken: Token? { get async throws(Failure) }
                    func refresh(_ rejected: Token) async throws(Failure) -> Token
                }

                #if DEBUG || MOCKING
                public final class TokenManagerMock: TokenManager, Sendable, MockWithable {
                    public var validToken: Token? {
                        get async throws(Failure) {
                            return try await $validToken.get.result()
                        }
                    }

                    #if DEBUG || MOCKING
                    public nonisolated let $validToken = Mocking.Mock.Property<Token?>.GetAsyncThrows<Failure>(subject: "validToken")
                    #endif
                    public func refresh(_ rejected: Token) async throws(Failure) -> Token {
                        return try await $refresh.result(rejected)
                    }

                    #if DEBUG || MOCKING
                    public nonisolated let $refresh = Mocking.Mock.Method<Token, Token>.AsyncThrows<Failure>(subject: "refresh(_:)")
                    #endif

                    public init() {
                    }

                    public func exclusive() -> TokenManagerMock {
                        $validToken.makeExclusive()
                        $refresh.makeExclusive()
                        return self
                    }

                    public var instance: TokenManagerMock {
                        self
                    }
                }
                #endif

                public enum TokenManagerKey: Dependencies.TestDependencyKey {
                    public static var testValue: any Authorization.TokenManager {
                        #if DEBUG || MOCKING
                        Authorization.TokenManagerMock().exclusive()
                        #else
                        fatalError("Authorization.TokenManager has no test value in this build.")
                        #endif
                    }
                }
            }

            extension Authorization.TokenManager {
                #if DEBUG || MOCKING
                public static var mock: Authorization.TokenManagerMock {
                    Authorization.TokenManagerMock()
                }
                #endif
            }

            extension Authorization.TokenManager {
                #if DEBUG || MOCKING
                public typealias Mock = Authorization.TokenManagerMock
                #endif
            }
            """
        }
    }

    @Test func `a protocol with an associated type is rejected`() {
        assertMacro(
            of: {
                """
                @MockableDependency
                protocol Store: Sendable {
                    associatedtype Value
                    func load() -> Value
                }
                """
            },
            diagnostics: [
                DiagnosticSpec(
                    message: """
                    @MockableDependency requires a protocol without associated types, because its key holds \
                    'any Protocol'.
                    """,
                    line: 1,
                    column: 1
                ),
            ],
            expansion: {
                """
                protocol Store: Sendable {
                    associatedtype Value
                    func load() -> Value
                }
                """
            }
        )
    }
}
#endif
