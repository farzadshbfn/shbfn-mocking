//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import Testing

// swiftlint:disable line_length
struct `Mockable Macro Generics` {
    // The nested `Mock` inherits the struct's generic context; a generic-typed value with no default wires
    // through the runtime-lenient `.get.result()` (its type may not be `Mockable`).
    @Test func genericStruct() {
        assertMacro {
            """
            @Mockable
            struct Box<Value> {
                var fallback: Value
                var make: () -> Value
            }
            """
        } expansion: {
            """
            struct Box<Value> {
                var fallback: Value
                var make: () -> Value
            }

            extension Box: Mockable {
                #if MOCKING
                final class Mock: Sendable, MockWithable {
                    nonisolated let $fallback = Mocking.Mock.Property<Value>.Get(subject: "fallback")

                    nonisolated let $make = Mocking.Mock.Method<Void, Value>.Sync(subject: "make()")

                    init() {
                    }

                    var instance: Box {
                        Box(mock: self)
                    }
                }

                static var mock: Box {
                    Mock().instance
                }

                init(mock: Mock) {
                    self.init(
                        fallback: mock.$fallback.get.result(),
                        make: {
                            mock.$make.result()
                        }
                    )
                }
                #endif
            }
            """
        }
    }

    @Test func genericProtocolWithAssociatedType() {
        assertMacro {
            """
            @Mockable
            protocol Repository {
                associatedtype Entity: Identifiable
                func fetch(id: Entity.ID) async throws -> Entity
            }
            """
        } expansion: {
            """
            protocol Repository {
                associatedtype Entity: Identifiable
                func fetch(id: Entity.ID) async throws -> Entity
            }

            #if MOCKING
            final class RepositoryMock<Entity: Identifiable>: Repository, Sendable, MockWithable {
                func fetch(id: Entity.ID) async throws -> Entity {
                    return try await $fetch.result(id)
                }

                #if MOCKING
                nonisolated let $fetch = Mocking.Mock.Method<Entity.ID, Entity>.AsyncThrows<any Swift.Error>(subject: "fetch(id:)")
                #endif

                init() {
                }

                var instance: RepositoryMock {
                    self
                }
            }
            #endif

            extension Repository {
                #if MOCKING
                typealias Mock = RepositoryMock
                #endif
            }
            """
        }
    }

    @Test func protocolWithPrimaryAndSecondaryAssociatedTypes() {
        assertMacro {
            """
            @Mockable
            protocol Store<Element> {
                associatedtype Element: Sendable
                associatedtype Failure: Error
                func get() async throws(Failure) -> Element
            }
            """
        } expansion: {
            """
            protocol Store<Element> {
                associatedtype Element: Sendable
                associatedtype Failure: Error
                func get() async throws(Failure) -> Element
            }

            #if MOCKING
            final class StoreMock<Element: Sendable, Failure: Swift.Error>: Store, Sendable, MockWithable {
                func get() async throws(Failure) -> Element {
                    return try await $get.result()
                }

                #if MOCKING
                nonisolated let $get = Mocking.Mock.Method<Void, Element>.AsyncThrows<Failure>(subject: "get()")
                #endif

                init() {
                }

                var instance: StoreMock {
                    self
                }
            }
            #endif

            extension Store {
                #if MOCKING
                typealias Mock = StoreMock
                #endif
            }
            """
        }
    }
}
// swiftlint:enable line_length
#endif
