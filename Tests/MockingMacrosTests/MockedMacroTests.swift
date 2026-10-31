//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
// swiftlint:disable file_length
import Testing

// swiftlint:disable:next type_body_length
struct `Mocked Macro` {
    @Test func propertyDefaultsToGetSet() {
        assertMacro {
            """
            struct Service {
                @MockedProperty var title: String
            }
            """
        } expansion: {
            """
            struct Service {
                var title: String {
                    get {
                        return $title.get.result()
                    }
                    set {
                        $title.set.result(newValue)
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $title = Mocking.Mock.Property<String>.GetSet(subject: "title")
                #endif
            }
            """
        }
    }

    @Test func propertyGetSetKind() {
        assertMacro {
            """
            struct Service {
                @MockedProperty(.getSet) var title: String
            }
            """
        } expansion: {
            """
            struct Service {
                var title: String {
                    get {
                        return $title.get.result()
                    }
                    set {
                        $title.set.result(newValue)
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $title = Mocking.Mock.Property<String>.GetSet(subject: "title")
                #endif
            }
            """
        }
    }

    @Test func propertyGetKind() {
        assertMacro {
            """
            struct Service {
                @MockedProperty(.get) var title: String
            }
            """
        } expansion: {
            """
            struct Service {
                var title: String {
                    get {
                        return $title.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $title = Mocking.Mock.Property<String>.Get(subject: "title")
                #endif
            }
            """
        }
    }

    @Test func propertyGetAsyncKind() {
        assertMacro {
            """
            struct Service {
                @MockedProperty(.getAsync) var status: String
            }
            """
        } expansion: {
            """
            struct Service {
                var status: String {
                    get async {
                        return await $status.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $status = Mocking.Mock.Property<String>.GetAsync(subject: "status")
                #endif
            }
            """
        }
    }

    @Test func propertyGetAsyncSetKind() {
        assertMacro {
            """
            struct Service {
                @MockedProperty(.getAsyncSet) var badge: Int
            }
            """
        } expansion: {
            """
            struct Service {
                var badge: Int {
                    get async {
                        return await $badge.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $badge = Mocking.Mock.Property<Int>.GetAsyncSet(subject: "badge")
                #endif
            }
            """
        }
    }

    @Test func propertyGetThrowsKind() {
        assertMacro {
            """
            struct Service {
                @MockedProperty(.getThrows) var token: String
            }
            """
        } expansion: {
            """
            struct Service {
                var token: String {
                    get throws {
                        return try $token.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $token = Mocking.Mock.Property<String>.GetThrows<any Swift.Error>(subject: "token")
                #endif
            }
            """
        }
    }

    @Test func propertyGetThrowsSetKind() {
        assertMacro {
            """
            struct Service {
                @MockedProperty(.getThrowsSet) var secret: String
            }
            """
        } expansion: {
            """
            struct Service {
                var secret: String {
                    get throws {
                        return try $secret.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $secret = Mocking.Mock.Property<String>.GetThrowsSet<any Swift.Error>(subject: "secret")
                #endif
            }
            """
        }
    }

    @Test func propertyTypedGetThrowsKind() {
        assertMacro {
            """
            enum ServiceError: Error {
                case unavailable
            }

            struct Service {
                @MockedProperty(.getThrows(ServiceError.self)) var session: String
            }
            """
        } expansion: {
            """
            enum ServiceError: Error {
                case unavailable
            }

            struct Service {
                var session: String {
                    get throws(ServiceError) {
                        return try $session.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $session = Mocking.Mock.Property<String>.GetThrows<ServiceError>(subject: "session")
                #endif
            }
            """
        }
    }

    @Test func propertyTypedGetThrowsSetKind() {
        assertMacro {
            """
            enum ServiceError: Error {
                case unavailable
            }

            struct Service {
                @MockedProperty(.getThrowsSet(ServiceError.self)) var credential: String
            }
            """
        } expansion: {
            // swiftlint:disable line_length
            """
            enum ServiceError: Error {
                case unavailable
            }

            struct Service {
                var credential: String {
                    get throws(ServiceError) {
                        return try $credential.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $credential = Mocking.Mock.Property<String>.GetThrowsSet<ServiceError>(subject: "credential")
                #endif
            }
            """
            // swiftlint:enable line_length
        }
    }

    @Test func methodGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func load(id: Int) -> String
            }
            """
        } expansion: {
            """
            struct Service {
                func load(id: Int) -> String {
                    return $load.result(id)
                }

                #if DEBUG || MOCKING
                nonisolated let $load = Mocking.Mock.Method<Int, String>.Sync(subject: "load(id:)")
                #endif
            }
            """
        }
    }

    @Test func asyncMethodGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func load(id: Int) async -> String
            }
            """
        } expansion: {
            """
            struct Service {
                func load(id: Int) async -> String {
                    return await $load.result(id)
                }

                #if DEBUG || MOCKING
                nonisolated let $load = Mocking.Mock.Method<Int, String>.Async(subject: "load(id:)")
                #endif
            }
            """
        }
    }

    @Test func asyncThrowsMethodGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func load(id: Int) async throws -> String
            }
            """
        } expansion: {
            // swiftlint:disable line_length
            """
            struct Service {
                func load(id: Int) async throws -> String {
                    return try await $load.result(id)
                }

                #if DEBUG || MOCKING
                nonisolated let $load = Mocking.Mock.Method<Int, String>.AsyncThrows<any Swift.Error>(subject: "load(id:)")
                #endif
            }
            """
            // swiftlint:enable line_length
        }
    }

    @Test func asyncTypedThrowsMethodGeneratesMockPeer() {
        assertMacro {
            """
            enum ServiceError: Error {
                case unavailable
            }

            struct Service {
                @MockedMethod func load(id: Int) async throws(ServiceError) -> String
            }
            """
        } expansion: {
            """
            enum ServiceError: Error {
                case unavailable
            }

            struct Service {
                func load(id: Int) async throws(ServiceError) -> String {
                    return try await $load.result(id)
                }

                #if DEBUG || MOCKING
                nonisolated let $load = Mocking.Mock.Method<Int, String>.AsyncThrows<ServiceError>(subject: "load(id:)")
                #endif
            }
            """
        }
    }

    @Test func multiArgMethodGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func fetch(api: String, id: Int) -> String
            }
            """
        } expansion: {
            // swiftlint:disable line_length
            """
            struct Service {
                func fetch(api: String, id: Int) -> String {
                    return $fetch.result((api: api, id: id))
                }

                #if DEBUG || MOCKING
                nonisolated let $fetch = Mocking.Mock.Method<(api: String, id: Int), String>.Sync(subject: "fetch(api:id:)")
                #endif
            }
            """
            // swiftlint:enable line_length
        }
    }

    // Single-element labeled tuples don't exist in Swift, so the lone argument must stay unlabeled.
    @Test func externalInternalParameterNamesGenerateMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func load(api id: Int) -> String
            }
            """
        } expansion: {
            """
            struct Service {
                func load(api id: Int) -> String {
                    return $load.result(id)
                }

                #if DEBUG || MOCKING
                nonisolated let $load = Mocking.Mock.Method<Int, String>.Sync(subject: "load(api id:)")
                #endif
            }
            """
        }
    }

    @Test func externalInternalMultiArgMethodGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func assign(label value: String, to target: Int) -> Bool
            }
            """
        } expansion: {
            // swiftlint:disable line_length
            """
            struct Service {
                func assign(label value: String, to target: Int) -> Bool {
                    return $assign.result((label: value, to: target))
                }

                #if DEBUG || MOCKING
                nonisolated let $assign = Mocking.Mock.Method<(label: String, to: Int), Bool>.Sync(subject: "assign(label value:to target:)")
                #endif
            }
            """
            // swiftlint:enable line_length
        }
    }

    @Test func optionalMethodGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func load(id: Int?) -> String?
            }
            """
        } expansion: {
            """
            struct Service {
                func load(id: Int?) -> String? {
                    return $load.result(id)
                }

                #if DEBUG || MOCKING
                nonisolated let $load = Mocking.Mock.Method<Int?, String?>.Sync(subject: "load(id:)")
                #endif
            }
            """
        }
    }

    @Test func implicitlyUnwrappedOptionalMethodGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func load(id: Int!) -> Int!
            }
            """
        } expansion: {
            """
            struct Service {
                func load(id: Int!) -> Int! {
                    return $load.result(id)
                }

                #if DEBUG || MOCKING
                nonisolated let $load = Mocking.Mock.Method<Int?, Int?>.Sync(subject: "load(id:)")
                #endif
            }
            """
        }
    }

    @Test func optionalPropertyGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedProperty var count: Int?
            }
            """
        } expansion: {
            """
            struct Service {
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
            }
            """
        }
    }

    @Test func implicitlyUnwrappedOptionalPropertyGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedProperty(.get) var badge: Int!
            }
            """
        } expansion: {
            """
            struct Service {
                var badge: Int! {
                    get {
                        return $badge.get.result()
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $badge = Mocking.Mock.Property<Int?>.Get(subject: "badge")
                #endif
            }
            """
        }
    }

    @Test func staticMethodGeneratesMockPeer() {
        assertMacro {
            """
            protocol CatalogAPI {
                static func item(id: Int) -> String
            }

            final class MockCatalogAPI: CatalogAPI, Sendable {
                @MockedMethod static func item(id: Int) -> String
            }
            """
        } expansion: {
            """
            protocol CatalogAPI {
                static func item(id: Int) -> String
            }

            final class MockCatalogAPI: CatalogAPI, Sendable {
                static func item(id: Int) -> String {
                    return $item.result(id)
                }

                #if DEBUG || MOCKING
                static let $item = Mocking.Mock.Method<Int, String>.Sync(subject: "static item(id:)")
                #endif
            }
            """
        }
    }

    @Test func staticPropertyGeneratesMockPeer() {
        assertMacro {
            """
            protocol CatalogAPI {
                static var prefix: String { get }
            }

            final class MockCatalogAPI: CatalogAPI, Sendable {
                @MockedProperty(.get) static var prefix: String
            }
            """
        } expansion: {
            """
            protocol CatalogAPI {
                static var prefix: String { get }
            }

            final class MockCatalogAPI: CatalogAPI, Sendable {
                static var prefix: String {
                    get {
                        return $prefix.get.result()
                    }
                }

                #if DEBUG || MOCKING
                static let $prefix = Mocking.Mock.Property<String>.Get(subject: "static prefix")
                #endif
            }
            """
        }
    }

    @Test func closureParameterThrowsGeneratesMockPeer() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func test(callback: @MainActor @escaping (Int) async throws -> String) throws
            }
            """
        } expansion: {
            // swiftlint:disable line_length
            """
            struct Service {
                func test(callback: @MainActor @escaping (Int) async throws -> String) throws {
                    return try $test.result(callback)
                }

                #if DEBUG || MOCKING
                nonisolated let $test = Mocking.Mock.Method<@MainActor (Int) async throws -> String, Void>.SyncThrows<any Swift.Error>(subject: "test(callback:)")
                #endif
            }
            """
            // swiftlint:enable line_length
        }
    }

    @Test func genericMethodErasesTypesToAny() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func test<A, B>(input: A) -> B
            }
            """
        } expansion: {
            """
            struct Service {
                func test<A, B>(input: A) -> B {
                    return $test.result(input as Any) as! B
                }

                #if DEBUG || MOCKING
                nonisolated let $test = Mocking.Mock.Method<Any, Any>.Sync(subject: "test(input:)")
                #endif
            }
            """
        }
    }

    @Test func genericMethodKeepsConcreteParameterTypes() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func map<T>(value: T, count: Int) -> T
            }
            """
        } expansion: {
            // swiftlint:disable line_length
            """
            struct Service {
                func map<T>(value: T, count: Int) -> T {
                    return $map.result((value: value as Any, count: count)) as! T
                }

                #if DEBUG || MOCKING
                nonisolated let $map = Mocking.Mock.Method<(value: Any, count: Int), Any>.Sync(subject: "map(value:count:)")
                #endif
            }
            """
            // swiftlint:enable line_length
        }
    }

    @Test func genericMethodWithTypedThrowsErasesFailure() {
        assertMacro {
            """
            struct Service {
                @MockedMethod func send<R>(_ request: R) async throws(Failure<R>) -> Output<R>
            }
            """
        } expansion: {
            """
            struct Service {
                func send<R>(_ request: R) async throws(Failure<R>) -> Output<R> {
                    do {
                        return try await $send.result(request as Any) as! Output<R>
                    } catch {
                        throw error as! Failure<R>
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $send = Mocking.Mock.Method<Any, Any>.AsyncThrows<any Swift.Error>(subject: "send(_:)")
                #endif
            }
            """
        }
    }

    @Test func genericMethodWithConcreteTypedThrowsKeepsFailure() {
        assertMacro {
            """
            enum ServiceError: Error {
                case failed
            }

            struct Service {
                @MockedMethod func transform<T>(_ value: T) throws(ServiceError) -> T
            }
            """
        } expansion: {
            // swiftlint:disable line_length
            """
            enum ServiceError: Error {
                case failed
            }

            struct Service {
                func transform<T>(_ value: T) throws(ServiceError) -> T {
                    return try $transform.result(value as Any) as! T
                }

                #if DEBUG || MOCKING
                nonisolated let $transform = Mocking.Mock.Method<Any, Any>.SyncThrows<ServiceError>(subject: "transform(_:)")
                #endif
            }
            """
            // swiftlint:enable line_length
        }
    }
}
#endif
