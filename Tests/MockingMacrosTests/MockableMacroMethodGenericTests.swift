//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if os(macOS) || os(Linux)
import Testing

struct `Mockable Macro Method Generics` {
    @Test func protocolWithGenericMethod() {
        assertMacro {
            """
            @Mockable
            protocol Mapper {
                func test<A, B>(input: A) -> B
            }
            """
        } expansion: {
            """
            protocol Mapper {
                func test<A, B>(input: A) -> B
            }

            #if DEBUG || MOCKING
            final class MapperMock: Mapper, Sendable, MockWithable {
                func test<A, B>(input: A) -> B {
                    return $test.result(input as Any) as! B
                }

                #if DEBUG || MOCKING
                nonisolated let $test = Mocking.Mock.Method<Any, Any>.Sync(subject: "test(input:)")
                #endif

                init() {
                }

                var instance: MapperMock {
                    self
                }
            }
            #endif

            extension Mapper {
                #if DEBUG || MOCKING
                static var mock: MapperMock {
                    MapperMock()
                }
                #endif
            }

            extension Mapper {
                #if DEBUG || MOCKING
                typealias Mock = MapperMock
                #endif
            }
            """
        }
    }

    @Test func protocolWithGenericMethodWhereClause() {
        assertMacro {
            """
            @Mockable
            protocol Encoder {
                func encode<T>(_ value: T) -> Data where T: Encodable
            }
            """
        } expansion: {
            """
            protocol Encoder {
                func encode<T>(_ value: T) -> Data where T: Encodable
            }

            #if DEBUG || MOCKING
            final class EncoderMock: Encoder, Sendable, MockWithable {
                func encode<T>(_ value: T) -> Data where T: Encodable {
                    return $encode.result(value as Any)
                }

                #if DEBUG || MOCKING
                nonisolated let $encode = Mocking.Mock.Method<Any, Data>.Sync(subject: "encode(_:)")
                #endif

                init() {
                }

                var instance: EncoderMock {
                    self
                }
            }
            #endif

            extension Encoder {
                #if DEBUG || MOCKING
                static var mock: EncoderMock {
                    EncoderMock()
                }
                #endif
            }

            extension Encoder {
                #if DEBUG || MOCKING
                typealias Mock = EncoderMock
                #endif
            }
            """
        }
    }

    @Test func protocolWithConstrainedGenericReturn() {
        assertMacro {
            """
            @Mockable
            protocol Factory {
                func make<T: Equatable>() -> T
            }
            """
        } expansion: {
            """
            protocol Factory {
                func make<T: Equatable>() -> T
            }

            #if DEBUG || MOCKING
            final class FactoryMock: Factory, Sendable, MockWithable {
                func make<T: Equatable>() -> T {
                    return $make.result() as! T
                }

                #if DEBUG || MOCKING
                nonisolated let $make = Mocking.Mock.Method<Void, Any>.Sync(subject: "make()")
                #endif

                init() {
                }

                var instance: FactoryMock {
                    self
                }
            }
            #endif

            extension Factory {
                #if DEBUG || MOCKING
                static var mock: FactoryMock {
                    FactoryMock()
                }
                #endif
            }

            extension Factory {
                #if DEBUG || MOCKING
                typealias Mock = FactoryMock
                #endif
            }
            """
        }
    }

    @Test func protocolWithConstrainedGenericReturnAndConcreteInput() {
        assertMacro {
            """
            @Mockable
            protocol Decoder {
                func decode<T: Decodable>(from data: Data) -> T
            }
            """
        } expansion: {
            """
            protocol Decoder {
                func decode<T: Decodable>(from data: Data) -> T
            }

            #if DEBUG || MOCKING
            final class DecoderMock: Decoder, Sendable, MockWithable {
                func decode<T: Decodable>(from data: Data) -> T {
                    return $decode.result(data) as! T
                }

                #if DEBUG || MOCKING
                nonisolated let $decode = Mocking.Mock.Method<Data, Any>.Sync(subject: "decode(from data:)")
                #endif

                init() {
                }

                var instance: DecoderMock {
                    self
                }
            }
            #endif

            extension Decoder {
                #if DEBUG || MOCKING
                static var mock: DecoderMock {
                    DecoderMock()
                }
                #endif
            }

            extension Decoder {
                #if DEBUG || MOCKING
                typealias Mock = DecoderMock
                #endif
            }
            """
        }
    }

    // swiftlint:disable:next function_body_length
    @Test func protocolWithGenericMethodTypedThrows() {
        assertMacro {
            """
            @Mockable
            protocol Client {
                func send<R: Request>(_ request: R) async throws(NetworkError<R.Failure>) -> Response<R.Output>
            }
            """
        } expansion: {
            """
            protocol Client {
                func send<R: Request>(_ request: R) async throws(NetworkError<R.Failure>) -> Response<R.Output>
            }

            #if DEBUG || MOCKING
            final class ClientMock: Client, Sendable, MockWithable {
                func send<R: Request>(_ request: R) async throws(NetworkError<R.Failure>) -> Response<R.Output> {
                    do {
                        return try await $send.result(request as Any) as! Response<R.Output>
                    } catch {
                        throw error as! NetworkError<R.Failure>
                    }
                }

                #if DEBUG || MOCKING
                nonisolated let $send = Mocking.Mock.Method<Any, Any>.AsyncThrows<any Swift.Error>(subject: "send(_:)")
                #endif

                init() {
                }

                var instance: ClientMock {
                    self
                }
            }
            #endif

            extension Client {
                #if DEBUG || MOCKING
                static var mock: ClientMock {
                    ClientMock()
                }
                #endif
            }

            extension Client {
                #if DEBUG || MOCKING
                typealias Mock = ClientMock
                #endif
            }
            """
        }
    }
}
#endif
