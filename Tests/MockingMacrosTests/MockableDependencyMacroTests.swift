//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import SwiftSyntaxMacrosGenericTestSupport
import Testing

struct `MockableDependency Macro` {
    @Test func `a nested protocol gets a key beside its mock, a Key alias, and exclusive()`() {
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

            extension Authorization.TokenManager {
                public typealias Key = Authorization.TokenManagerKey
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
                    @MockableDependency requires a protocol without associated types or a non-generic struct, \
                    because its key holds one concrete value type.
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

    @Test func `a nested struct gets a peer mock, a key, and a Key alias`() {
        assertMacro {
            """
            extension Authorization {
                @MockableDependency
                public struct Session: Sendable {
                    public var refresh: @Sendable (_ token: Token) async throws(Failure) -> Token
                }
            }
            """
        } expansion: {
            """
            extension Authorization {
                public struct Session: Sendable {
                    public var refresh: @Sendable (_ token: Token) async throws(Failure) -> Token
                }

                #if DEBUG || MOCKING
                public final class SessionMock: Sendable, MockWithable {
                    public nonisolated let $refresh = Mocking.Mock.Method<Token, Token>.AsyncThrows<Failure>(subject: "refresh(token:)")

                    public init() {
                    }

                    public var instance: Session {
                        let mock = self
                        return Session(
                            refresh: { (token: Token) async throws(Failure) in
                                try await mock.$refresh.result(token)
                            }
                        )
                    }

                    public func exclusive() -> SessionMock {
                        $refresh.makeExclusive()
                        return self
                    }
                }
                #endif

                public enum SessionKey: Dependencies.TestDependencyKey {
                    public static var testValue: Authorization.Session {
                        #if DEBUG || MOCKING
                        Authorization.SessionMock().exclusive().instance
                        #else
                        fatalError("Authorization.Session has no test value in this build.")
                        #endif
                    }
                }
            }

            extension Authorization.Session: Mockable {
                #if DEBUG || MOCKING
                public typealias Mock = Authorization.SessionMock

                public static var mock: Authorization.Session {
                    Mock().instance
                }
                #endif
            }

            extension Authorization.Session {
                public typealias Key = Authorization.SessionKey
            }
            """
        }
    }
}
#endif
