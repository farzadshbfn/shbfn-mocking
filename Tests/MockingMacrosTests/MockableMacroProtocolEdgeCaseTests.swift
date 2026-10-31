//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import Testing

// swiftlint:disable function_body_length line_length
struct `Mockable Macro Protocol Edge Cases` {
    @Test func protocolNestedInExtension() {
        assertMacro {
            """
            struct FeatureNamespace {}

            extension FeatureNamespace {
                @Mockable
                protocol Store {
                    var count: Int { get }
                }
            }
            """
        } expansion: {
            """
            struct FeatureNamespace {}

            extension FeatureNamespace {
                protocol Store {
                    var count: Int { get }
                }

                #if DEBUG || MOCKING
                final class StoreMock: Store, Sendable, MockWithable {
                    var count: Int {
                        get {
                            return $count.get.result()
                        }
                    }

                    #if DEBUG || MOCKING
                    nonisolated let $count = Mocking.Mock.Property<Int>.Get(subject: "count")
                    #endif

                    init() {
                    }

                    var instance: StoreMock {
                        self
                    }
                }
                #endif
            }

            extension FeatureNamespace.Store {
                #if DEBUG || MOCKING
                static var mock: FeatureNamespace.StoreMock {
                    FeatureNamespace.StoreMock()
                }
                #endif
            }

            extension FeatureNamespace.Store {
                #if DEBUG || MOCKING
                typealias Mock = FeatureNamespace.StoreMock
                #endif
            }
            """
        }
    }

    @Test func `preserves nested Error in typed throws and qualifies Swift.Error for untyped throws`() {
        assertMacro {
            """
            enum Authentication {
                enum Error: Swift.Error {}

                @Mockable
                protocol Transport {
                    func send(_ request: URLRequest) async throws(Error) -> (Data, HTTPURLResponse)
                    func ping() async throws
                }
            }
            """
        } expansion: {
            """
            enum Authentication {
                enum Error: Swift.Error {}
                protocol Transport {
                    func send(_ request: URLRequest) async throws(Error) -> (Data, HTTPURLResponse)
                    func ping() async throws
                }

                #if DEBUG || MOCKING
                final class TransportMock: Transport, Sendable, MockWithable {
                    func send(_ request: URLRequest) async throws(Error) -> (Data, HTTPURLResponse) {
                        return try await $send.result(request)
                    }

                    #if DEBUG || MOCKING
                    nonisolated let $send = Mocking.Mock.Method<URLRequest, (Data, HTTPURLResponse)>.AsyncThrows<Error>(subject: "send(_:)")
                    #endif
                    func ping() async throws {
                        return try await $ping.result()
                    }

                    #if DEBUG || MOCKING
                    nonisolated let $ping = Mocking.Mock.Method<Void, Void>.AsyncThrows<any Swift.Error>(subject: "ping()")
                    #endif

                    init() {
                    }

                    var instance: TransportMock {
                        self
                    }
                }
                #endif
            }

            extension Authentication.Transport {
                #if DEBUG || MOCKING
                static var mock: Authentication.TransportMock {
                    Authentication.TransportMock()
                }
                #endif
            }

            extension Authentication.Transport {
                #if DEBUG || MOCKING
                typealias Mock = Authentication.TransportMock
                #endif
            }
            """
        }
    }

    @Test func protocolWithOptionalAndIUOTypes() {
        assertMacro {
            """
            @Mockable
            protocol OptionalService {
                var count: Int? { get set }
                func load(id: Int?) -> Int!
            }
            """
        } expansion: {
            """
            protocol OptionalService {
                var count: Int? { get set }
                func load(id: Int?) -> Int!
            }

            #if DEBUG || MOCKING
            final class OptionalServiceMock: OptionalService, Sendable, MockWithable {
                var count: Int? {
                    get {
                        return $count.get.result()
                    }
                    set {
                        $count.set.result(newValue)
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $count = Mocking.Mock.Property<Int?>.GetSet(subject: "count")
                #endif
                func load(id: Int?) -> Int! {
                    return $load.result(id)
                }

                #if DEBUG || MOCKING
                nonisolated let $load = Mocking.Mock.Method<Int?, Int?>.Sync(subject: "load(id:)")
                #endif

                init() {
                }

                var instance: OptionalServiceMock {
                    self
                }
            }
            #endif

            extension OptionalService {
                #if DEBUG || MOCKING
                static var mock: OptionalServiceMock {
                    OptionalServiceMock()
                }
                #endif
            }

            extension OptionalService {
                #if DEBUG || MOCKING
                typealias Mock = OptionalServiceMock
                #endif
            }
            """
        }
    }

    @Test func protocolWithStaticRequirementsGeneratesMockClass() {
        assertMacro {
            """
            @Mockable
            protocol CatalogAPI {
                static var prefix: String { get }
                static func item(id: Int) -> String
            }
            """
        } expansion: {
            """
            protocol CatalogAPI {
                static var prefix: String { get }
                static func item(id: Int) -> String
            }

            #if DEBUG || MOCKING
            final class CatalogAPIMock: CatalogAPI, Sendable, MockWithable {
                static var prefix: String {
                    get {
                        return $prefix.get.result()
                    }
                }

                #if DEBUG || MOCKING
                static let $prefix = Mocking.Mock.Property<String>.Get(subject: "static prefix")
                #endif
                static func item(id: Int) -> String {
                    return $item.result(id)
                }

                #if DEBUG || MOCKING
                static let $item = Mocking.Mock.Method<Int, String>.Sync(subject: "static item(id:)")
                #endif

                init() {
                }

                var instance: CatalogAPIMock {
                    self
                }
            }
            #endif

            extension CatalogAPI {
                #if DEBUG || MOCKING
                static var mock: CatalogAPIMock {
                    CatalogAPIMock()
                }
                #endif
            }

            extension CatalogAPI {
                #if DEBUG || MOCKING
                typealias Mock = CatalogAPIMock
                #endif
            }
            """
        }
    }

    // A member's own @MockedMethod wins, so an overloaded protocol keeps its shape and still mocks.
    @Test func namedResolvesAnOverloadedMethod() {
        assertMacro {
            """
            @Mockable
            protocol Worker {
                func run()
                @MockedMethod(named: "runForce") func run(force: Bool)
            }
            """
        } expansion: {
            """
            protocol Worker {
                func run()
                func run(force: Bool)
            }

            #if DEBUG || MOCKING
            final class WorkerMock: Worker, Sendable, MockWithable {
                func run() {
                    return $run.result()
                }

                #if DEBUG || MOCKING
                nonisolated let $run = Mocking.Mock.Method<Void, Void>.Sync(subject: "run()")
                #endif
                func run(force: Bool) {
                    return $runForce.result(force)
                }

                #if DEBUG || MOCKING
                nonisolated let $runForce = Mocking.Mock.Method<Bool, Void>.Sync(subject: "run(force:)")
                #endif

                init() {
                }

                var instance: WorkerMock {
                    self
                }
            }
            #endif

            extension Worker {
                #if DEBUG || MOCKING
                static var mock: WorkerMock {
                    WorkerMock()
                }
                #endif
            }

            extension Worker {
                #if DEBUG || MOCKING
                typealias Mock = WorkerMock
                #endif
            }
            """
        }
    }

    @Test func asyncThrowingProperty() {
        assertMacro {
            """
            @Mockable
            protocol Vault {
                var token: String { get async throws }
            }
            """
        } expansion: {
            """
            protocol Vault {
                var token: String { get async throws }
            }

            #if DEBUG || MOCKING
            final class VaultMock: Vault, Sendable, MockWithable {
                var token: String {
                    get async throws {
                        return try await $token.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $token = Mocking.Mock.Property<String>.GetAsyncThrows<any Swift.Error>(subject: "token")
                #endif

                init() {
                }

                var instance: VaultMock {
                    self
                }
            }
            #endif

            extension Vault {
                #if DEBUG || MOCKING
                static var mock: VaultMock {
                    VaultMock()
                }
                #endif
            }

            extension Vault {
                #if DEBUG || MOCKING
                typealias Mock = VaultMock
                #endif
            }
            """
        }
    }
}
// swiftlint:enable function_body_length line_length
#endif
