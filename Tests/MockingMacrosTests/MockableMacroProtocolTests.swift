//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import Testing

// swiftlint:disable line_length function_body_length
// swiftlint:disable:next type_body_length
struct `Mockable Macro Protocol` {
    @Test func protocolGeneratesMockClass() {
        assertMacro {
            """
            @Mockable
            protocol Greeter {
                var greeting: String { get }
                func greet(name: String) -> String
            }
            """
        } expansion: {
            """
            protocol Greeter {
                var greeting: String { get }
                func greet(name: String) -> String
            }

            #if MOCKING
            final class GreeterMock: Greeter, Sendable, MockWithable {
                var greeting: String {
                    get {
                        return $greeting.get.result()
                    }
                }

                #if MOCKING
                nonisolated let $greeting = Mocking.Mock.Property<String>.Get(subject: "greeting")
                #endif
                func greet(name: String) -> String {
                    return $greet.result(name)
                }

                #if MOCKING
                nonisolated let $greet = Mocking.Mock.Method<String, String>.Sync(subject: "greet(name:)")
                #endif

                init() {
                }

                var instance: GreeterMock {
                    self
                }
            }
            #endif

            extension Greeter {
                #if MOCKING
                static var mock: GreeterMock {
                    GreeterMock()
                }
                #endif
            }

            extension Greeter {
                #if MOCKING
                typealias Mock = GreeterMock
                #endif
            }
            """
        }
    }

    // Single-element labeled tuples don't exist in Swift, so the lone argument must stay unlabeled.
    @Test func protocolWithLabeledSingleParameterMethod() {
        assertMacro {
            """
            @Mockable
            protocol ConfigProviding {
                func config(for key: String) -> Int?
            }
            """
        } expansion: {
            """
            protocol ConfigProviding {
                func config(for key: String) -> Int?
            }

            #if MOCKING
            final class ConfigProvidingMock: ConfigProviding, Sendable, MockWithable {
                func config(for key: String) -> Int? {
                    return $config.result(key)
                }

                #if MOCKING
                nonisolated let $config = Mocking.Mock.Method<String, Int?>.Sync(subject: "config(for key:)")
                #endif

                init() {
                }

                var instance: ConfigProvidingMock {
                    self
                }
            }
            #endif

            extension ConfigProviding {
                #if MOCKING
                static var mock: ConfigProvidingMock {
                    ConfigProvidingMock()
                }
                #endif
            }

            extension ConfigProviding {
                #if MOCKING
                typealias Mock = ConfigProvidingMock
                #endif
            }
            """
        }
    }

    @Test func protocolWithVoidReturningMethod() {
        assertMacro {
            """
            @Mockable
            protocol Resettable {
                func reset()
            }
            """
        } expansion: {
            """
            protocol Resettable {
                func reset()
            }

            #if MOCKING
            final class ResettableMock: Resettable, Sendable, MockWithable {
                func reset() {
                    return $reset.result()
                }

                #if MOCKING
                nonisolated let $reset = Mocking.Mock.Method<Void, Void>.Sync(subject: "reset()")
                #endif

                init() {
                }

                var instance: ResettableMock {
                    self
                }
            }
            #endif

            extension Resettable {
                #if MOCKING
                static var mock: ResettableMock {
                    ResettableMock()
                }
                #endif
            }

            extension Resettable {
                #if MOCKING
                typealias Mock = ResettableMock
                #endif
            }
            """
        }
    }

    @Test func protocolNestedInEnum() {
        assertMacro {
            """
            enum Feature {
                @Mockable
                protocol API {
                    func fetch(api: String, id: Int) -> String
                }
            }
            """
        } expansion: {
            """
            enum Feature {
                protocol API {
                    func fetch(api: String, id: Int) -> String
                }

                #if MOCKING
                final class APIMock: API, Sendable, MockWithable {
                    func fetch(api: String, id: Int) -> String {
                        return $fetch.result((api: api, id: id))
                    }

                    #if MOCKING
                    nonisolated let $fetch = Mocking.Mock.Method<(api: String, id: Int), String>.Sync(subject: "fetch(api:id:)")
                    #endif

                    init() {
                    }

                    var instance: APIMock {
                        self
                    }
                }
                #endif
            }

            extension Feature.API {
                #if MOCKING
                static var mock: Feature.APIMock {
                    Feature.APIMock()
                }
                #endif
            }

            extension Feature.API {
                #if MOCKING
                typealias Mock = Feature.APIMock
                #endif
            }
            """
        }
    }

    @Test func publicProtocolGeneratesPublicMockSurface() {
        assertMacro {
            """
            @Mockable
            public protocol APIProtocol {
                var status: String { get }
                func createToken(_ input: String) async throws -> String
            }
            """
        } expansion: {
            """
            public protocol APIProtocol {
                var status: String { get }
                func createToken(_ input: String) async throws -> String
            }

            #if MOCKING
            public final class APIProtocolMock: APIProtocol, Sendable, MockWithable {
                public var status: String {
                    get {
                        return $status.get.result()
                    }
                }

                #if MOCKING
                public nonisolated let $status = Mocking.Mock.Property<String>.Get(subject: "status")
                #endif
                public func createToken(_ input: String) async throws -> String {
                    return try await $createToken.result(input)
                }

                #if MOCKING
                public nonisolated let $createToken = Mocking.Mock.Method<String, String>.AsyncThrows<any Swift.Error>(subject: "createToken(_:)")
                #endif

                public init() {
                }

                public var instance: APIProtocolMock {
                    self
                }
            }
            #endif

            extension APIProtocol {
                #if MOCKING
                public static var mock: APIProtocolMock {
                    APIProtocolMock()
                }
                #endif
            }

            extension APIProtocol {
                #if MOCKING
                public typealias Mock = APIProtocolMock
                #endif
            }
            """
        }
    }

    @Test func packageProtocolGeneratesPackageMockSurface() {
        assertMacro {
            """
            @Mockable
            package protocol APIProtocol {
                var status: String { get }
                func createToken(_ input: String) async throws -> String
            }
            """
        } expansion: {
            """
            package protocol APIProtocol {
                var status: String { get }
                func createToken(_ input: String) async throws -> String
            }

            #if MOCKING
            package final class APIProtocolMock: APIProtocol, Sendable, MockWithable {
                package var status: String {
                    get {
                        return $status.get.result()
                    }
                }

                #if MOCKING
                package nonisolated let $status = Mocking.Mock.Property<String>.Get(subject: "status")
                #endif
                package func createToken(_ input: String) async throws -> String {
                    return try await $createToken.result(input)
                }

                #if MOCKING
                package nonisolated let $createToken = Mocking.Mock.Method<String, String>.AsyncThrows<any Swift.Error>(subject: "createToken(_:)")
                #endif

                package init() {
                }

                package var instance: APIProtocolMock {
                    self
                }
            }
            #endif

            extension APIProtocol {
                #if MOCKING
                package static var mock: APIProtocolMock {
                    APIProtocolMock()
                }
                #endif
            }

            extension APIProtocol {
                #if MOCKING
                package typealias Mock = APIProtocolMock
                #endif
            }
            """
        }
    }
}
#endif
// swiftlint:enable line_length function_body_length
