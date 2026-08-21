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

            #if MOCKING
            final class MapperMock: Mapper, Sendable, MockWithable {
                func test<A, B>(input: A) -> B {
                    return $test.result(input as Any) as! B
                }

                #if MOCKING
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
                #if MOCKING
                static var mock: MapperMock {
                    MapperMock()
                }
                #endif
            }

            extension Mapper {
                #if MOCKING
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

            #if MOCKING
            final class EncoderMock: Encoder, Sendable, MockWithable {
                func encode<T>(_ value: T) -> Data where T: Encodable {
                    return $encode.result(value as Any)
                }

                #if MOCKING
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
                #if MOCKING
                static var mock: EncoderMock {
                    EncoderMock()
                }
                #endif
            }

            extension Encoder {
                #if MOCKING
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

            #if MOCKING
            final class FactoryMock: Factory, Sendable, MockWithable {
                func make<T: Equatable>() -> T {
                    return $make.result() as! T
                }

                #if MOCKING
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
                #if MOCKING
                static var mock: FactoryMock {
                    FactoryMock()
                }
                #endif
            }

            extension Factory {
                #if MOCKING
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

            #if MOCKING
            final class DecoderMock: Decoder, Sendable, MockWithable {
                func decode<T: Decodable>(from data: Data) -> T {
                    return $decode.result(data) as! T
                }

                #if MOCKING
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
                #if MOCKING
                static var mock: DecoderMock {
                    DecoderMock()
                }
                #endif
            }

            extension Decoder {
                #if MOCKING
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

            #if MOCKING
            final class ClientMock: Client, Sendable, MockWithable {
                func send<R: Request>(_ request: R) async throws(NetworkError<R.Failure>) -> Response<R.Output> {
                    do {
                        return try await $send.result(request as Any) as! Response<R.Output>
                    } catch {
                        throw error as! NetworkError<R.Failure>
                    }
                }

                #if MOCKING
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
                #if MOCKING
                static var mock: ClientMock {
                    ClientMock()
                }
                #endif
            }

            extension Client {
                #if MOCKING
                typealias Mock = ClientMock
                #endif
            }
            """
        }
    }
}
#endif
