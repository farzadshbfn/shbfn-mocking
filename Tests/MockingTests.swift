//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

// swiftlint:disable file_length

import Mocking
import Testing

@Suite
struct `Mock.Method` {
    @Test
    func `sync mock records calls and returns configured value`() {
        let mock = Mock.Method<Int, String>.Sync()
        mock.returns = "hello"

        #expect(mock.result(42) == "hello")
        #expect(mock.callCount == 1)
        #expect(mock.args == 42)
        #expect(mock.history == [42])
    }

    @Test
    func `sync mock exposes named args for multi-parameter calls`() {
        let mock = Mock.Method<(api: String, id: Int), String>.Sync()
        mock.returns = "ok"

        _ = mock.result((api: "khiar", id: 7))

        #expect(mock.args?.api == "khiar")
        #expect(mock.args?.id == 7)
    }

    @Test
    func `sync mock exposes external argument labels in args`() {
        let mock = Mock.Method<(label: String, to: Int), Bool>.Sync()
        mock.returns = true

        _ = mock.result((label: "home", to: 3))

        #expect(mock.args?.label == "home")
        #expect(mock.args?.to == 3)
    }

    @Test
    func `sync mock uses onCall`() {
        let mock = Mock.Method<Int, Int>.Sync()
        mock.onCall = { $0 * 2 }

        #expect(mock.result(21) == 42)
    }

    @Test
    func `optional return can be configured to return nil via some(nil)`() {
        let mock = Mock.Method<Void, Int?>.Sync()
        mock.returns = .some(nil)

        #expect(mock.result() == nil)
    }

    @Test
    func `returns = nil clears optional return configuration`() {
        let mock = Mock.Method<Void, Int?>.Sync()
        mock.returns = .some(1)
        mock.returns = nil

        #expect(mock.result() == nil)
    }

    @Test
    func `optional parameter is recorded in call history`() {
        let mock = Mock.Method<Int?, String>.Sync()
        mock.returns = "ok"

        #expect(mock.result(nil) == "ok")
        #expect(mock.args == .some(nil))
        #expect(mock.history == [nil])
    }

    @Test
    func `implicitly unwrapped optional maps to Optional in mock generics`() {
        let mock = Mock.Method<Int?, Int?>.Sync()
        mock.returns = 99

        #expect(mock.result(1) == 99)
    }

    @Test
    func `non-exclusive sync mock falls back to mock`() {
        let mock = Mock.Method<Void, Int>.Sync()

        #expect(mock.result() == 0)
    }

    @Test
    func `exclusive sync mock fails when not configured`() {
        let mock = Mock.Method<Void, Int>.Sync()
        mock.isExclusive = true
        #expect(mock.returns == nil)
        #expect(mock.onCall == nil)
        #expect(mock.callCount == 0)
    }

    @Test
    func `isExclusive can be toggled to enable lenient fallback`() {
        let mock = Mock.Method<Void, Int>.Sync()
        mock.isExclusive = true
        mock.isExclusive = false

        #expect(mock.result() == 0)
        #expect(mock.callCount == 1)
    }

    @Test
    func `isExclusive can be toggled on async invocations`() async {
        let mock = Mock.Method<Void, Int>.Async()
        mock.isExclusive = true
        mock.isExclusive = false

        #expect(await mock.result() == 0)
        #expect(mock.callCount == 1)
    }

    @Test
    func `async mock returns configured value`() async {
        let mock = Mock.Method<String, Bool>.Async()
        mock.returns = true

        #expect(await mock.result("enabled") == true)
        #expect(mock.callCount == 1)
        #expect(mock.args == "enabled")
    }

    @Test
    func `returns and onCall are mutually exclusive`() {
        let mock = Mock.Method<Void, Int>.Sync()
        mock.returns = 1
        mock.onCall = { _ in 2 }
        #expect(mock.returns == nil)
        #expect(mock.onCall != nil)
    }

    @Test
    func `sync throws mock throws configured error`() {
        enum TestFailure: Error { case failed }

        let mock = Mock.Method<Void, Int>.SyncThrows<TestFailure>()
        mock.throws = .failed

        #expect(throws: TestFailure.failed) {
            try mock.result()
        }
        #expect(mock.callCount == 1)
    }

    @Test
    func `async throws mock throws configured error`() async {
        enum TestFailure: Error { case failed }

        let mock = Mock.Method<Void, Int>.AsyncThrows<TestFailure>()
        mock.throws = .failed

        await #expect(throws: TestFailure.failed) {
            try await mock.result()
        }
        #expect(mock.callCount == 1)
    }

    @Test
    func `throws is mutually exclusive with returns and onCall`() {
        enum TestFailure: Error { case failed }

        let mock = Mock.Method<Void, Int>.SyncThrows<TestFailure>()
        mock.returns = 1
        mock.throws = .failed
        #expect(mock.returns == nil)
        #expect(mock.throws == .failed)

        mock.throws = .failed
        mock.onCall = { _ in 2 }
        #expect(mock.throws == nil)
        #expect(mock.onCall != nil)
    }

    @Test
    func `call tracker record is thread-safe`() async {
        let tracker = CallTracker<Int>()

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 100 {
                group.addTask {
                    tracker.record(index)
                }
            }
        }

        #expect(tracker.count == 100)
        #expect(tracker.inputHistory.count == 100)
    }

    @Test
    func `configuration is thread-safe`() async {
        let mock = Mock.Method<Void, Int>.Sync()
        mock.returns = 0

        await withTaskGroup(of: Void.self) { group in
            for index in 1 ... 100 {
                group.addTask {
                    mock.returns = index
                    mock.onCall = { _ in index }
                    mock.throws = nil
                    _ = mock.returns
                    _ = mock.onCall
                }
            }
            for _ in 0 ..< 100 {
                group.addTask {
                    _ = mock.result()
                }
            }
        }

        #expect(mock.callCount == 100)
    }
}

@Suite
struct `Mock.Property` {
    @Test
    func `get property returns configured value`() {
        let property = Mock.Property<String>.Get()
        property.get.returns = "mock"

        #expect(property.get.result() == "mock")
        #expect(property.get.callCount == 1)
    }

    @Test
    func `get-set property records setter calls`() {
        let property = Mock.Property<Int>.GetSet()
        property.get.returns = 7
        property.set.onCall = { _ in }

        #expect(property.get.result() == 7)
        property.set.result(42)

        #expect(property.set.callCount == 1)
        #expect(property.set.args == 42)
        #expect(property.set.history == [42])
    }

    @Test
    func `optional get property can be configured to return nil via some(nil)`() {
        let property = Mock.Property<Int?>.Get()
        property.get.returns = .some(nil)

        #expect(property.get.result() == nil)
    }

    @Test
    func `optional get-set property records nil setter arguments`() {
        let property = Mock.Property<Int?>.GetSet()
        property.get.returns = .some(3)
        property.set.onCall = { _ in }

        property.set.result(nil)

        #expect(property.set.callCount == 1)
        #expect(property.set.args == .some(nil))
    }

    @Test
    func `non-exclusive get property falls back to mock`() {
        let property = Mock.Property<Bool>.Get()
        #expect(property.get.result() == false)
    }

    @Test
    func `throws get property throws configured error`() {
        enum TestFailure: Error { case failed }

        let property = Mock.Property<String>.GetThrows<any Error>()
        property.get.throws = TestFailure.failed

        #expect(throws: TestFailure.failed) {
            try property.get.result()
        }
        #expect(property.get.callCount == 1)
    }

    @Test
    func `typed throws get property throws configured error`() {
        enum TestFailure: Error { case failed }

        let property = Mock.Property<String>.GetThrows<TestFailure>()
        property.get.throws = .failed

        #expect(throws: TestFailure.failed) {
            try property.get.result()
        }
        #expect(property.get.callCount == 1)
    }

    @Test
    func `async get property returns configured value`() async {
        let property = Mock.Property<String>.GetAsync()
        property.get.returns = "ready"

        #expect(await property.get.result() == "ready")
        #expect(property.get.callCount == 1)
    }

    @Test
    func `async get-set property records setter calls`() async {
        let property = Mock.Property<Int>.GetAsyncSet()
        property.get.returns = 1
        property.set.onCall = { _ in }

        #expect(await property.get.result() == 1)
        property.set.result(2)

        #expect(property.set.callCount == 1)
        #expect(property.set.args == 2)
    }

    @Test
    func `throws get-set property throws and records setter calls`() {
        enum TestFailure: Error { case failed }

        let property = Mock.Property<String>.GetThrowsSet<any Error>()
        property.get.throws = TestFailure.failed
        property.set.onCall = { _ in }

        #expect(throws: TestFailure.failed) {
            try property.get.result()
        }
        property.set.result("value")

        #expect(property.get.callCount == 1)
        #expect(property.set.callCount == 1)
        #expect(property.set.args == "value")
    }

    @Test
    func `typed throws get-set property throws and records setter calls`() {
        enum TestFailure: Error { case failed }

        let property = Mock.Property<String>.GetThrowsSet<TestFailure>()
        property.get.throws = .failed
        property.set.onCall = { _ in }

        #expect(throws: TestFailure.failed) {
            try property.get.result()
        }
        property.set.result("value")

        #expect(property.get.callCount == 1)
        #expect(property.set.callCount == 1)
        #expect(property.set.args == "value")
    }
}

@Suite
struct `Cross-module Mockable` {
    @Test
    func `non-exclusive method uses Mockable mock from another module`() {
        let mock = Mock.Method<Void, WidgetID>.Sync()

        #expect(mock.result() == WidgetID("fixture-default-id"))
    }

    @Test
    func `non-exclusive method uses composite Mockable mock from another module`() {
        let mock = Mock.Method<Void, Widget>.Sync()

        let widget = mock.result()
        #expect(widget == Widget(id: WidgetID("fixture-default-id"), score: 42))
    }

    @Test
    func `non-exclusive property uses Mockable mock from another module`() {
        let property = Mock.Property<Widget>.Get()

        #expect(property.get.result() == Widget.mock)
    }

    @Test
    func `non-exclusive method uses Mockable mock for foreign Mockable types`() {
        let mock = Mock.Method<Void, StrictWidget>.Sync()

        #expect(mock.result() == StrictWidget.mock)
    }

    @Test
    func `non-exclusive method does not leniently fallback without Mockable`() {
        let mock = Mock.Method<Void, PlainWidget>.Sync()

        #expect(PlainWidget.self is any Mockable.Type == false)
        #expect(mock.returns == nil)
        #expect(mock.onCall == nil)
        #expect(mock.callCount == 0)
    }
}

@Mockable
struct SampleConfig {
    var timeout: Int
    var label: String
}

@Mockable
protocol Greeter {
    var greeting: String { get }
    func greet(name: String) -> String
}

enum Feature {
    @Mockable
    protocol API {
        func fetch(api: String, id: Int) -> String
    }
}

enum Network {
    enum APIError: Error, Equatable {
        case networkError
    }

    @Mockable
    protocol API {
        func fetch() throws -> String
    }
}

struct FeatureNamespace {}

extension FeatureNamespace {
    @Mockable
    protocol Store {
        var count: Int { get }
    }
}

enum MockedServiceError: Error {
    case unavailable
}

struct MockedPropertyService {
    @MockedProperty(.get) var label: String
    @MockedProperty(.getSet) var title: String
    @MockedProperty(.getAsync) var status: String
    @MockedProperty(.getAsyncSet) var badge: Int
    @MockedProperty(.getThrows) var token: String
    @MockedProperty(.getThrowsSet) var secret: String
    @MockedProperty(.getThrows(MockedServiceError.self)) var session: String
    @MockedProperty(.getThrowsSet(MockedServiceError.self)) var credential: String
}

struct MockedMethodService {
    @MockedMethod func load(id: Int) -> String
    @MockedMethod func fetch(id: Int) async -> String
    @MockedMethod func download(id: Int) async throws -> String
    @MockedMethod func reserve(id: Int, room: String) async throws(MockedServiceError) -> String
}

struct MockedMultiArgService {
    @MockedMethod func fetch(api: String, id: Int) -> String
}

@Mockable
protocol NamedWorker {
    func run()
    @MockedMethod(named: "runForce") func run(force: Bool)
    var state: Int { get }
    @MockedProperty(named: "stateLabel") var state2: String { get }
}

struct NamedPeerService {
    @MockedMethod(named: "loadByID") func load(id: Int) -> String
    @MockedProperty(named: "readableLabel", .get) var label: String
    @MockedProperty(named: "editableTitle") var title: String
}

@Mockable
protocol Beacon {
    static func ping() -> String
    func ping() -> String
}

@Mockable
protocol CatalogAPI {
    static var prefix: String { get }
    static func item(id: Int) -> String
}

@Mockable
struct TokenStore {
    var clientID: String
    var token: () async throws -> String
    var refresh: (_ force: Bool) async -> Void
}

enum WitnessAuthError: Error, Equatable {
    case missingToken
}

// Typed `throws(E)` on a witness closure property: the `$` peer and the generated thunk both carry `E`.
@Mockable
struct TypedThrowsWitness {
    var token: () async throws(WitnessAuthError) -> String
    var read: (_ key: String) throws(WitnessAuthError) -> String
    var save: (String) throws(WitnessAuthError) -> Void
    var refresh: (_ force: Bool) async -> Void
}

@Mockable
struct SyncWitness {
    var compute: (Int) -> Int
    var limit: Int = 7
}

@Mockable
struct Box<Value> {
    var fallback: Value
    var make: () -> Value
}

struct Entry: Identifiable, Equatable, Sendable {
    let id: String
}

@Mockable
protocol ConfigProviding {
    func config(for key: String) -> Int?
}

@Mockable
protocol Repository {
    associatedtype Entity: Identifiable
    func fetch(id: Entity.ID) async throws -> Entity
    func save(_ entity: Entity) async throws
}

enum StoreError: Error {
    case empty
}

@Mockable
protocol Store<Element> {
    associatedtype Element: Sendable & Equatable
    associatedtype Failure: Error
    func get() async throws(Failure) -> Element
}

@Mockable
protocol Mapper {
    func test<A, B>(input: A) -> B
    func map<T>(value: T, count: Int) -> T
    func transform<T>(_ value: T) throws(MockedServiceError) -> T
    func identity<T: Equatable>(_ value: T) -> T
}

enum PipelineError<Payload>: Error {
    case rejected
}

@Mockable
protocol Pipeline {
    func send<R>(_ request: R) async throws(PipelineError<R>) -> R
}

@Suite
struct `Macros` {
    @Test
    func `synthesizes struct mock conforming to Mockable`() {
        let _: any Mockable.Type = SampleConfig.self
        #expect(SampleConfig.mock.timeout == 0)
        #expect(SampleConfig.mock.label == "")
    }

    @Test
    func `value-only struct exposes a configurable controller`() {
        let config = SampleConfig.Mock().with {
            $0.$timeout.get.returns = 30
        }.instance

        #expect(config.timeout == 30)
        #expect(config.label == "")
    }

    @Test
    func `synthesizes Sendable protocol mock with configurable peers`() {
        let mock = Greeter.Mock().with {
            $0.$greeting.get.returns = "hello"
            $0.$greet.returns = "hello, world"
        }
        let sendable: any Sendable = mock

        #expect(sendable is GreeterMock)
        #expect(mock.instance.greeting == "hello")
        #expect(mock.greet(name: "world") == "hello, world")
        #expect(mock.$greet.callCount == 1)
        #expect(mock.$greet.args == "world")
    }

    @Test
    func `mocks method whose single parameter has distinct external and internal names`() {
        let mock = ConfigProviding.Mock().with {
            $0.$config.returns = .some(7)
        }

        #expect(mock.config(for: "search") == 7)
        #expect(mock.$config.callCount == 1)
        #expect(mock.$config.args == "search")
    }

    @Test
    func `synthesizes Sendable mock for protocol nested in enum`() {
        let mock = Feature.API.Mock().with {
            $0.$fetch.returns = "payload"
        }
        let sendable: any Sendable = mock

        #expect(sendable is Feature.APIMock)
        #expect(mock.fetch(api: "khiar", id: 42) == "payload")
        #expect(mock.$fetch.callCount == 1)
        #expect(mock.$fetch.args?.api == "khiar")
        #expect(mock.$fetch.args?.id == 42)
    }

    @Test
    func `throws configured error when MockWithable configures protocol mock`() throws {
        let mock = Network.API.Mock().with {
            $0.$fetch.throws = Network.APIError.networkError
        }

        #expect(throws: Network.APIError.networkError) {
            try mock.fetch()
        }
        #expect(mock.$fetch.callCount == 1)
    }

    @Test
    func `records count for protocol nested in extension`() {
        let mock = FeatureNamespace.Store.Mock().with {
            $0.$count.get.returns = 3
        }

        #expect(mock.count == 3)
        #expect(mock.$count.get.callCount == 1)
    }

    @Test
    func `records all mocked property kinds`() async throws {
        var service = MockedPropertyService()
        service.$label.get.returns = "hello"
        service.$title.get.returns = "hello"
        service.$title.set.onCall = { _ in }
        service.$status.get.returns = "ready"
        service.$badge.get.returns = 1
        service.$badge.set.onCall = { _ in }
        service.$token.get.throws = MockedServiceError.unavailable
        service.$session.get.throws = MockedServiceError.unavailable
        service.$secret.get.throws = MockedServiceError.unavailable
        service.$secret.set.onCall = { _ in }
        service.$credential.get.throws = MockedServiceError.unavailable
        service.$credential.set.onCall = { _ in }

        #expect(service.label == "hello")
        #expect(service.$label.get.callCount == 1)

        #expect(service.title == "hello")
        service.title = "world"
        #expect(service.$title.get.callCount == 1)
        #expect(service.$title.set.callCount == 1)
        #expect(service.$title.set.args == "world")

        #expect(await service.status == "ready")
        #expect(service.$status.get.callCount == 1)

        #expect(await service.badge == 1)
        service.$badge.set.result(2)
        #expect(service.$badge.get.callCount == 1)
        #expect(service.$badge.set.callCount == 1)
        #expect(service.$badge.set.args == 2)

        #expect(throws: MockedServiceError.unavailable) { try service.token }
        #expect(service.$token.get.callCount == 1)

        #expect(throws: MockedServiceError.unavailable) { try service.session }
        #expect(service.$session.get.callCount == 1)

        #expect(throws: MockedServiceError.unavailable) { try service.secret }
        service.$secret.set.result("value")
        #expect(service.$secret.get.callCount == 1)
        #expect(service.$secret.set.callCount == 1)
        #expect(service.$secret.set.args == "value")

        #expect(throws: MockedServiceError.unavailable) { try service.credential }
        service.$credential.set.result("value")
        #expect(service.$credential.get.callCount == 1)
        #expect(service.$credential.set.callCount == 1)
        #expect(service.$credential.set.args == "value")
    }

    @Test
    func `records sync, async, and throwing method calls`() async throws {
        let service = MockedMethodService()
        service.$load.returns = "payload"
        service.$fetch.returns = "payload"
        service.$download.returns = "payload"
        service.$reserve.returns = "held"

        #expect(service.load(id: 42) == "payload")
        #expect(service.$load.callCount == 1)
        #expect(service.$load.args == 42)

        #expect(await service.fetch(id: 7) == "payload")
        #expect(service.$fetch.callCount == 1)
        #expect(service.$fetch.args == 7)

        #expect(try await service.download(id: 3) == "payload")
        #expect(service.$download.callCount == 1)
        #expect(service.$download.args == 3)

        service.$download.throws = MockedServiceError.unavailable
        await #expect(throws: MockedServiceError.unavailable) {
            try await service.download(id: 3)
        }
        #expect(service.$download.callCount == 2)
        #expect(service.$download.args == 3)

        #expect(try await service.reserve(id: 9, room: "A12") == "held")
        #expect(service.$reserve.callCount == 1)
        #expect(service.$reserve.args?.id == 9)
        #expect(service.$reserve.args?.room == "A12")
    }

    @Test
    func `records named args for multi-parameter sync method`() {
        let service = MockedMultiArgService()
        service.$fetch.returns = "ok"

        #expect(service.fetch(api: "khiar", id: 7) == "ok")
        #expect(service.$fetch.callCount == 1)
        #expect(service.$fetch.args?.api == "khiar")
        #expect(service.$fetch.args?.id == 7)
    }

    @Test
    func `a static member and an instance member may share a name`() {
        BeaconMock.$ping.returns = "static"
        let sut = Beacon.Mock().with {
            $0.$ping.returns = "instance"
        }

        #expect(BeaconMock.ping() == "static")
        #expect(sut.ping() == "instance")
        #expect(BeaconMock.$ping.callCount == 1)
        #expect(sut.$ping.callCount == 1)
    }

    @Test
    func `records static protocol members`() {
        CatalogAPIMock.$prefix.get.returns = "catalog"
        CatalogAPIMock.$item.returns = "catalog-item"

        #expect(CatalogAPIMock.prefix == "catalog")
        #expect(CatalogAPIMock.item(id: 3) == "catalog-item")
        #expect(CatalogAPIMock.$prefix.get.callCount == 1)
        #expect(CatalogAPIMock.$item.callCount == 1)
        #expect(CatalogAPIMock.$item.args == 3)
    }

    @Test
    func `records closure parameter for throwing method`() throws {
        struct Service {
            @MockedMethod func test(callback: @MainActor @escaping (Int) async throws -> String) throws
        }

        let service = Service()
        let callback: @MainActor (Int) async throws -> String = { _ in "ok" }
        try service.test(callback: callback)

        #expect(service.$test.callCount == 1)
        #expect(service.$test.args != nil)
    }
}

@Suite
struct `Witness structs` {
    @Test
    func `controller configures closures and values, instance carries them`() async throws {
        let mock = TokenStore.Mock().with {
            $0.$clientID.get.returns = "client-7"
            $0.$token.returns = "abc"
        }
        let store = mock.instance

        #expect(store.clientID == "client-7")
        #expect(try await store.token() == "abc")
        await store.refresh(true)

        #expect(mock.$token.callCount == 1)
        #expect(mock.$refresh.callCount == 1)
        #expect(mock.$refresh.args == true)
    }

    @Test
    func `init(mock:) is equivalent to instance`() {
        let mock = SyncWitness.Mock().with {
            $0.$compute.returns = 42
        }
        let sut = SyncWitness(mock: mock)

        #expect(sut.compute(1) == 42)
        #expect(mock.$compute.callCount == 1)
        #expect(mock.$compute.args == 1)
    }

    @Test
    func `closure onCall handler runs`() {
        let mock = SyncWitness.Mock().with {
            $0.$compute.onCall = { $0 * 2 }
        }

        #expect(mock.instance.compute(21) == 42)
    }

    @Test
    func `lenient fixture defaults values and closures`() async throws {
        let _: any Mockable.Type = TokenStore.self
        let store = TokenStore.mock

        #expect(store.clientID == "")
        #expect(try await store.token() == "")
    }

    @Test
    func `typed throws closure property keeps its failure type`() async throws {
        let mock = TypedThrowsWitness.Mock().with {
            $0.$token.throws = .missingToken
            $0.$read.returns = "value"
            $0.$save.throws = .missingToken
        }
        let store = mock.instance

        // The knob is typed, so `.missingToken` needs no spelling and the thrown value needs no cast.
        await #expect(throws: WitnessAuthError.missingToken) { try await store.token() }
        #expect(try store.read("key") == "value")
        #expect(throws: WitnessAuthError.missingToken) { try store.save("value") }

        do throws(WitnessAuthError) {
            _ = try await store.token()
            Issue.record("expected a typed failure")
        } catch {
            #expect(error == .missingToken)
        }

        #expect(mock.$read.args == "key")
        #expect(mock.$save.callCount == 1)
    }

    @Test
    func `typed throws closure property takes a throwing onCall handler`() throws {
        let mock = TypedThrowsWitness.Mock().with {
            // The typed `onCall` overload wins, so the handler can throw the declared failure type.
            $0.$read.onCall = { key throws(WitnessAuthError) in
                guard key == "known" else { throw .missingToken }
                return "value"
            }
        }
        let store = mock.instance

        #expect(try store.read("known") == "value")
        #expect(throws: WitnessAuthError.missingToken) { try store.read("other") }
        #expect(mock.$read.callCount == 2)
    }

    @Test
    func `declared default wins over Mockable fixture`() {
        let store = SyncWitness.mock

        #expect(store.limit == 7)
    }
}

@Suite
struct `Generic mocks` {
    @Test
    func `generic struct configures and verifies through the controller`() {
        let mock = Box<Int>.Mock().with {
            $0.$fallback.get.returns = 7
            $0.$make.returns = 9
        }
        let box = mock.instance

        #expect(box.fallback == 7)
        #expect(box.make() == 9)
        #expect(mock.$make.callCount == 1)
    }

    @Test
    func `generic struct fixture is lenient for Mockable instantiations`() {
        #expect(Box<Int>.mock.fallback == 0)
    }

    @Test
    func `generic protocol binds associated type at Mock()`() async throws {
        let repo = Repository.Mock<Entry>().with {
            $0.$fetch.returns = Entry(id: "e1")
        }

        let entity = try await repo.fetch(id: "e1")

        #expect(entity == Entry(id: "e1"))
        #expect(repo.$fetch.callCount == 1)
        #expect(repo.$fetch.args == "e1")

        try await repo.save(Entry(id: "e2"))
        #expect(repo.$save.args == Entry(id: "e2"))
    }

    @Test
    func `primary associated type mock binds all parameters and satisfies some Store`() async throws {
        let store = Store.Mock<Int, StoreError>().with {
            $0.$get.returns = 42
        }

        #expect(try await store.get() == 42)
        #expect(store.$get.callCount == 1)

        // The mock satisfies the primary-associated-type existential used at injection sites.
        func firstValue(_ store: some Store<Int>) async throws -> Int {
            try await store.get()
        }
        let injected = Store.Mock<Int, StoreError>().with { $0.$get.returns = 5 }
        #expect(try await firstValue(injected.instance) == 5)
    }

    @Test
    func `generic protocol propagates typed throws`() async {
        let store = Store.Mock<Int, StoreError>().with {
            $0.$get.throws = StoreError.empty
        }

        await #expect(throws: StoreError.empty) {
            try await store.get()
        }
    }
}

@Suite
struct `Mockable Generic Methods` {
    @Test
    func `configures erased return and records Any arguments`() {
        let mock = Mapper.Mock().with {
            $0.$test.returns = "hello"
        }

        let result: String = mock.test(input: 42)

        #expect(result == "hello")
        #expect(mock.$test.callCount == 1)
        #expect(mock.$test.args as? Int == 42)
    }

    @Test
    func `keeps concrete parameters alongside erased generics`() {
        let mock = Mapper.Mock().with {
            $0.$map.onCall = { inputs in
                let value = inputs.value as? String ?? ""
                return String(repeating: value, count: inputs.count)
            }
        }

        #expect(mock.map(value: "ab", count: 3) == "ababab")
        #expect(mock.$map.args?.value as? String == "ab")
        #expect(mock.$map.args?.count == 3)
    }

    @Test
    func `concrete typed throws stay typed on erased peers`() {
        let mock = Mapper.Mock().with {
            $0.$transform.throws = .unavailable
        }

        #expect(throws: MockedServiceError.unavailable) {
            try mock.transform(1)
        }
        #expect(mock.$transform.callCount == 1)
        #expect(mock.$transform.args as? Int == 1)
    }

    @Test
    func `constrained generic return erases and force-casts at the call site`() {
        let mock = Mapper.Mock().with {
            $0.$identity.returns = 99
        }

        let result: Int = mock.identity(7)

        #expect(result == 99)
        #expect(mock.$identity.callCount == 1)
        #expect(mock.$identity.args as? Int == 7)
    }

    @Test
    func `erased typed throws rethrow the configured failure`() async {
        let mock = Pipeline.Mock().with {
            $0.$send.throws = PipelineError<Int>.rejected
        }

        await #expect(throws: PipelineError<Int>.rejected) {
            try await mock.send(7)
        }
        #expect(mock.$send.callCount == 1)
        #expect(mock.$send.args as? Int == 7)
    }

    @Test
    func `erased async generic method returns configured value`() async throws {
        let mock = Pipeline.Mock().with {
            $0.$send.returns = 99
        }

        let result: Int = try await mock.send(1)
        #expect(result == 99)
        #expect(mock.$send.args as? Int == 1)
    }
}

@Mockable
protocol VoidWorker {
    func run()
    func runForced(force: Bool)
    func save() throws
    func fetch() async
    func store() async throws
}

@Suite
struct `Void Output Leniency` {
    @Test
    func `sync zero-argument Void method is lenient`() {
        let mock = VoidWorker.Mock()

        mock.run()

        #expect(mock.$run.callCount == 1)
    }

    @Test
    func `sync Void method with an argument is lenient`() {
        let mock = VoidWorker.Mock()

        mock.runForced(force: true)

        #expect(mock.$runForced.callCount == 1)
        #expect(mock.$runForced.args == true)
    }

    @Test
    func `throwing sync zero-argument Void method is lenient`() throws {
        let mock = VoidWorker.Mock()

        try mock.save()

        #expect(mock.$save.callCount == 1)
    }

    @Test
    func `async zero-argument Void method is lenient`() async {
        let mock = VoidWorker.Mock()

        await mock.fetch()

        #expect(mock.$fetch.callCount == 1)
    }

    @Test
    func `throwing async zero-argument Void method is lenient`() async throws {
        let mock = VoidWorker.Mock()

        try await mock.store()

        #expect(mock.$store.callCount == 1)
    }

    @Test
    func `standalone sync Void method double is lenient`() {
        let mock = Mock.Method<Void, Void>.Sync()

        mock.result()

        #expect(mock.callCount == 1)
    }

    @Test
    func `standalone async Void method double is lenient`() async {
        let mock = Mock.Method<Void, Void>.Async()

        await mock.result()

        #expect(mock.callCount == 1)
    }

    @Test
    func `standalone typed-throws sync Void method double is lenient`() throws {
        let mock = Mock.Method<Void, Void>.SyncThrows<MockedServiceError>()

        try mock.result()

        #expect(mock.callCount == 1)
    }

    @Test
    func `standalone typed-throws async Void method double is lenient`() async throws {
        let mock = Mock.Method<Void, Void>.AsyncThrows<MockedServiceError>()

        try await mock.result()

        #expect(mock.callCount == 1)
    }

    @Test
    func `exclusive sync Void method traps when not configured`() async {
        await #expect(processExitsWith: .failure) {
            let mock = Mock.Method<Void, Void>.Sync()
            mock.isExclusive = true
            mock.result()
        }
    }

    @Test
    func `exclusive async Void method traps when not configured`() async {
        await #expect(processExitsWith: .failure) {
            let mock = Mock.Method<Void, Void>.Async()
            mock.isExclusive = true
            await mock.result()
        }
    }

    @Test
    func `exclusive Void protocol method traps when not configured`() async {
        await #expect(processExitsWith: .failure) {
            let mock = VoidWorker.Mock()
            mock.$fetch.isExclusive = true
            await mock.fetch()
        }
    }
}

@Suite
struct `Named Peers` {
    @Test
    func `named overrides the peer of a hand-written method`() {
        let sut = NamedPeerService()
        sut.$loadByID.returns = "ok"

        #expect(sut.load(id: 7) == "ok")
        #expect(sut.$loadByID.callCount == 1)
        #expect(sut.$loadByID.args == 7)
    }

    @Test
    func `named overrides the peer of a hand-written property`() {
        let sut = NamedPeerService()
        sut.$readableLabel.get.returns = "label"

        #expect(sut.label == "label")
        #expect(sut.$readableLabel.get.callCount == 1)
    }

    @Test
    func `named alone keeps the inferred property kind`() {
        var sut = NamedPeerService()
        sut.$editableTitle.get.returns = "title"

        #expect(sut.title == "title")
        sut.title = "next"
        #expect(sut.$editableTitle.set.args == "next")
    }

    @Test
    func `named resolves an overloaded protocol method`() {
        let sut = NamedWorker.Mock()

        sut.run()
        sut.run(force: true)

        #expect(sut.$run.callCount == 1)
        #expect(sut.$runForce.callCount == 1)
        #expect(sut.$runForce.args == true)
    }

    @Test
    func `named on a protocol property wins over the generated name`() {
        let sut = NamedWorker.Mock().with {
            $0.$state.get.returns = 3
            $0.$stateLabel.get.returns = "label"
        }

        #expect(sut.state == 3)
        #expect(sut.state2 == "label")
    }
}
