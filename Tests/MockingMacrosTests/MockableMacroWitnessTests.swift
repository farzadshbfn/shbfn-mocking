//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import Testing

// swiftlint:disable line_length function_body_length
// A "witness struct" carries behavior in closure-typed stored properties. `@Mockable` generates a nested
// `Mock` controller (with `$` peers), an `init(mock:)`, an `instance`, and a lenient `static var mock`.
struct `Mockable Macro Witness` {

    @Test func typedThrowsClosureProperty() {
        assertMacro {
            """
            @Mockable
            struct TokenStore {
                var token: () async throws(AuthError) -> String
                var save: (_ key: String, _ value: Int) throws(AuthError) -> Void
                var refresh: (_ force: Bool) async -> Void
            }
            """
        } expansion: {
            """
            struct TokenStore {
                var token: () async throws(AuthError) -> String
                var save: (_ key: String, _ value: Int) throws(AuthError) -> Void
                var refresh: (_ force: Bool) async -> Void
            }

            extension TokenStore: Mockable {
                #if MOCKING
                final class Mock: Sendable, MockWithable {
                    nonisolated let $token = Mocking.Mock.Method<Void, String>.AsyncThrows<AuthError>(subject: "token()")

                    nonisolated let $save = Mocking.Mock.Method<(key: String, value: Int), Void>.SyncThrows<AuthError>(subject: "save(key:value:)")

                    nonisolated let $refresh = Mocking.Mock.Method<Bool, Void>.Async(subject: "refresh(force:)")

                    init() {
                    }

                    var instance: TokenStore {
                        TokenStore(mock: self)
                    }
                }

                static var mock: TokenStore {
                    Mock().instance
                }

                init(mock: Mock) {
                    self.init(
                        token: { () async throws(AuthError) in
                            try await mock.$token.result()
                        },
                        save: { (key: String, value: Int) throws(AuthError) in
                            try mock.$save.result((key: key, value: value))
                        },
                        refresh: { force in
                            await mock.$refresh.result(force)
                        }
                    )
                }
                #endif
            }
            """
        }
    }
    @Test func closureAndValueProperties() {
        assertMacro {
            """
            @Mockable
            struct TokenStore {
                var clientID: String
                var token: () async throws -> String
                var refresh: (_ force: Bool) async -> Void
            }
            """
        } expansion: {
            """
            struct TokenStore {
                var clientID: String
                var token: () async throws -> String
                var refresh: (_ force: Bool) async -> Void
            }

            extension TokenStore: Mockable {
                #if MOCKING
                final class Mock: Sendable, MockWithable {
                    nonisolated let $clientID = Mocking.Mock.Property<String>.Get(subject: "clientID")

                    nonisolated let $token = Mocking.Mock.Method<Void, String>.AsyncThrows<any Swift.Error>(subject: "token()")

                    nonisolated let $refresh = Mocking.Mock.Method<Bool, Void>.Async(subject: "refresh(force:)")

                    init() {
                    }

                    var instance: TokenStore {
                        TokenStore(mock: self)
                    }
                }

                static var mock: TokenStore {
                    Mock().instance
                }

                init(mock: Mock) {
                    self.init(
                        clientID: mock.$clientID.get.returns ?? .mock,
                        token: {
                            try await mock.$token.result()
                        },
                        refresh: { force in
                            await mock.$refresh.result(force)
                        }
                    )
                }
                #endif
            }
            """
        }
    }

    @Test func syncThrowingClosureWithLabeledArgs() {
        assertMacro {
            """
            @Mockable
            struct Parser {
                var parse: (_ text: String, _ strict: Bool) throws -> Int
            }
            """
        } expansion: {
            """
            struct Parser {
                var parse: (_ text: String, _ strict: Bool) throws -> Int
            }

            extension Parser: Mockable {
                #if MOCKING
                final class Mock: Sendable, MockWithable {
                    nonisolated let $parse = Mocking.Mock.Method<(text: String, strict: Bool), Int>.SyncThrows<any Swift.Error>(subject: "parse(text:strict:)")

                    init() {
                    }

                    var instance: Parser {
                        Parser(mock: self)
                    }
                }

                static var mock: Parser {
                    Mock().instance
                }

                init(mock: Mock) {
                    self.init(
                        parse: { text, strict in
                            try mock.$parse.result((text: text, strict: strict))
                        }
                    )
                }
                #endif
            }
            """
        }
    }

    @Test func valuePropertyWithDeclaredDefault() {
        assertMacro {
            """
            @Mockable
            struct Config {
                var retryLimit: Int = 3
                var handler: () -> Void
            }
            """
        } expansion: {
            """
            struct Config {
                var retryLimit: Int = 3
                var handler: () -> Void
            }

            extension Config: Mockable {
                #if MOCKING
                final class Mock: Sendable, MockWithable {
                    nonisolated let $retryLimit = Mocking.Mock.Property<Int>.Get(subject: "retryLimit")

                    nonisolated let $handler = Mocking.Mock.Method<Void, Void>.Sync(subject: "handler()")

                    init() {
                    }

                    var instance: Config {
                        Config(mock: self)
                    }
                }

                static var mock: Config {
                    Mock().instance
                }

                init(mock: Mock) {
                    self.init(
                        retryLimit: mock.$retryLimit.get.returns ?? 3,
                        handler: {
                            mock.$handler.result()
                        }
                    )
                }
                #endif
            }
            """
        }
    }

    @Test func publicWitnessStructPropagatesAccess() {
        assertMacro {
            """
            @Mockable
            public struct Client {
                public var send: (String) -> Void
            }
            """
        } expansion: {
            """
            public struct Client {
                public var send: (String) -> Void
            }

            extension Client: Mockable {
                #if MOCKING
                public final class Mock: Sendable, MockWithable {
                    public nonisolated let $send = Mocking.Mock.Method<String, Void>.Sync(subject: "send(_:)")

                    public init() {
                    }

                    public var instance: Client {
                        Client(mock: self)
                    }
                }

                public static var mock: Client {
                    Mock().instance
                }

                public init(mock: Mock) {
                    self.init(
                        send: { arg0 in
                            mock.$send.result(arg0)
                        }
                    )
                }
                #endif
            }
            """
        }
    }

    @Test func witnessStructPropagatesPerPropertyAccess() {
        assertMacro {
            """
            @Mockable
            public struct Client {
                public var send: (String) -> Void
                package var retryLimit: Int
                internal var timeout: Double
                fileprivate var handler: () -> Void
            }
            """
        } expansion: {
            """
            public struct Client {
                public var send: (String) -> Void
                package var retryLimit: Int
                internal var timeout: Double
                fileprivate var handler: () -> Void
            }

            extension Client: Mockable {
                #if MOCKING
                public final class Mock: Sendable, MockWithable {
                    public nonisolated let $send = Mocking.Mock.Method<String, Void>.Sync(subject: "send(_:)")

                    package nonisolated let $retryLimit = Mocking.Mock.Property<Int>.Get(subject: "retryLimit")

                    internal nonisolated let $timeout = Mocking.Mock.Property<Double>.Get(subject: "timeout")

                    fileprivate nonisolated let $handler = Mocking.Mock.Method<Void, Void>.Sync(subject: "handler()")

                    public init() {
                    }

                    public var instance: Client {
                        Client(mock: self)
                    }
                }

                public static var mock: Client {
                    Mock().instance
                }

                public init(mock: Mock) {
                    self.init(
                        send: { arg0 in
                            mock.$send.result(arg0)
                        },
                        retryLimit: mock.$retryLimit.get.returns ?? .mock,
                        timeout: mock.$timeout.get.returns ?? .mock,
                        handler: {
                            mock.$handler.result()
                        }
                    )
                }
                #endif
            }
            """
        }
    }
}
// swiftlint:enable line_length function_body_length
#endif
