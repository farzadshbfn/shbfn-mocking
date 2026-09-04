---
name: shbfn-mocking
description: Use when a Swift test needs a test double from the shbfn-mocking package — mocking a protocol or struct, building a fixture, controlling what a call returns or throws, verifying calls (callCount, args, history), or waiting on a call with waitForCall. Also use to wire the MOCKING define, and for "type has no member 'Mock'" or "Mock return value not configured".
license: MIT
---

# Mocking

`Mocking` generates test doubles for Swift protocols and structs. Mock through this
package. Do not hand-roll fakes, and do not add a second mocking library.

Test style (naming, `sut`, Given/When/Then, `confirmation`) lives in the
**`shbfn-testing`** skill.

## 1. Integrate

```swift
.package(url: "https://github.com/farzadshbfn/shbfn-mocking.git", branch: "main"),

.target(
    name: "MyFeature",
    dependencies: [.product(name: "Mocking", package: "shbfn-mocking")],
    swiftSettings: [.define("MOCKING", .when(configuration: .debug))]
),
```

Add both lines to **every target that uses the macro**: the production target that
declares the type, and the test target. The macro puts all generated code inside
`#if MOCKING`. Without the define the code compiles, but `Type.Mock()` does not exist.
When `Type.Mock()` is "not found", check the define first.

The package needs swift-tools 6.2 and iOS 26 / macOS 15. Call sites `import Mocking`.

## 2. Define

Mark the dependency `@Mockable` where it is declared, in the production module. Prefer
typed `throws`: it types the `.throws` knob, so a test writes `.throws = .missingToken`.

```swift
@Mockable
protocol TokenStoring {
    var clientID: String { get }
    func token() async throws(AuthError) -> String
    func refresh(force: Bool) async
}
```

| Spelling | Meaning |
|----------|---------|
| `Type.Mock()` | Controller. Configure and verify through `$` peers. Conforms to the protocol |
| `controller.instance` | The value to inject |
| `Type.mock` | Lenient ready instance, no configuration |

Pick the shape by need:

- **Protocol** — a dependency with behavior. Each member gets a `$` peer.
- **Struct with closure properties** — a witness. Each closure behaves like a method.
- **Struct with value properties** — a fixture. `Type.mock` fills each property from its
  type's `.mock`; nested `@Mockable` structs compose.
- **Generic protocol** — bind each `associatedtype` at the call: `Repository.Mock<Entry>()`.
- **Hand-written struct** — `@MockedMethod` or `@MockedProperty` on one member.
- **A closure or callback** — build a `Mock.Method` directly. Never invent a protocol only
  to mock it.

### `$` peers

| Member | Peer |
|--------|------|
| `func fetch(id:)` | `mock.$fetch` |
| read-only `var token` | `mock.$token.get` |
| read-write `var title` | `mock.$title.get`, `mock.$title.set` |

Call the public API (`fetch`, `token`). Configure and inspect through the peer.

Two members with one name claim one peer, and the macro reports an error with a fix-it.
Give one member its own peer with `named:` (a string literal) and keep the declaration:

```swift
@Mockable
protocol Worker {
    func run()
    @MockedMethod(named: "runForce")
    func run(force: Bool)
}
// mock.run(force: true); mock.$runForce.callCount == 1
```

On `@MockedProperty`, `named:` comes first: `@MockedProperty(named: "x", .get)`. A static
and an instance member may share a name. An `@Mockable` struct takes no `named:`, because
stored properties never collide.

### Structs

A struct gets the same grammar: `Type.Mock()`, `$` peers, `init(mock:)`, `.instance`, and
`.mock`. Each stored property becomes a peer:

- **Closure property**: a method peer with `.returns`, `.throws`, `.onCall`, `callCount`,
  `args`, `history`.
- **Value property**: `$name.get`, configure-only. The mock reads it once when
  `.instance` or `.mock` builds the struct, so `callCount` has no meaning. Unconfigured, it
  falls back to the declared default, else to `Type.mock`.

```swift
SampleConfig.mock  // SampleConfig(timeout: 0, label: "")
SampleConfig.Mock().with { $0.$timeout.get.returns = 30 }.instance
```

When a property type cannot chain `.mock`, conform by hand:

```swift
extension WidgetID: Mockable {
    static var mock: WidgetID { WidgetID("fixture-default-id") }
}
```

### Hand-written types

```swift
struct Service {
    @MockedMethod func load(id: Int) -> String
    @MockedMethod func download(id: Int) async throws -> String
    @MockedProperty(.get) var label: String
    @MockedProperty(.getSet) var title: String
    @MockedProperty(.getThrows(ServiceError.self)) var session: String
}
```

`@MockedMethod` reads `async` and `throws` from the signature. `@MockedProperty` kinds:
`.get`, `.getSet`, `.getAsync`, `.getAsyncSet`, `.getThrows`, `.getThrowsSet`,
`.getAsyncThrows`. Omit the kind and it infers `.getSet` when a setter exists, else
`.get`. A bare throwing kind means `any Error`; pass the failure type in parentheses to
type it, as `.getThrows(MyError.self)`. Inside an `@Mockable` protocol the kind comes from
the requirement, so `{ get async throws }` needs no attribute.

### Generics

- **Generic struct**: `Box<Int>.Mock()`. A value property of generic type with no default
  resolves at runtime: configured value, else `Mockable` default, else trap.
- **Generic protocol**: each `associatedtype` becomes a `Mock` parameter, in declaration
  order: `Store.Mock<Item, StoreError>()`. Never `Store<Item>.Mock<StoreError>()`. There
  is no `.mock`. Injection sites keep `some Store<Item>`.
- **Generic methods** erase their parameters. `args` is `Any`, so cast:
  `mock.$test.args as? Int == 42`. `.returns` must hold the type the caller expects.
- **Static requirements plus associated types** are unsupported (macro error).

### Mocking without a type

A `$` peer *is* a `Mock.Method` or `Mock.Property`. For a single callback, build one:

- `Mock.Method<Inputs, Output>.Sync`, `.Async`, `.SyncThrows<Failure>`, `.AsyncThrows<Failure>`
- `Mock.Property<Value>.Get`, `.GetSet`, `.GetAsync`, `.GetAsyncSet`, `.GetThrows<Failure>`,
  `.GetThrowsSet<Failure>`, `.GetAsyncThrows<Failure>`

```swift
let onProgress = Mock.Method<Double, Void>.Sync(subject: "onProgress")
let sut = Downloader(onProgress: { onProgress.result($0) })
sut.run()
#expect(onProgress.history == [0.5, 1.0])
```

Invoke with `result(_:)`, or `result()` when `Inputs` is `Void`. The optional `subject`
names the peer in `waitForCall` timeout messages.

## 3. Use in a test

Configure with **one** `.with { }` per controller, before you build the `sut`. A nested
mock gets its own `.with { }` inside the parent closure.

```swift
let store = TokenStoring.Mock().with {
    $0.$token.throws = .missingToken
}
let sut = TokenManager(store: store.instance)

try await sut.ensureToken()

#expect(store.$refresh.callCount == 1)
```

### Configure

| Knob | Effect |
|------|--------|
| `.returns` | Fixed value on every call |
| `.throws` | Throws on every call |
| `.onCall` | Computes the result from the inputs |

Only one knob is active. Setting one clears the others.

- Optional return: `.returns = .some(nil)` returns `nil`. `.returns = nil` *clears* it.
- Read-only properties have `get` only. The mock records setter calls by itself; use
  `$name.set.onCall` only for custom setter behavior.
- A `Void` method needs no configuration. `refresh(force:)` above is unconfigured.

**`isExclusive`** defaults to `false`: an unconfigured peer returns the `Mockable` default
(`0`, `""`, `false`, `nil`, or the struct fixture). Set `isExclusive = true` when such a
silent default would hide missing setup. Every call then needs a configuration, or the
mock traps with "Mock return value not configured".

### Verify

| Member | Meaning |
|--------|---------|
| `$name.callCount` | Recorded calls |
| `$name.args` | Inputs of the most recent call, `nil` before the first |
| `$name.history` | Inputs of every call, in order |

Properties: `mock.$title.get.callCount`, `mock.$title.set.args`. With two or more
parameters `args` is a labeled tuple (`args?.api`); with one it is the value itself.

### Waiting on unstructured concurrency

Prefer `confirmation`. When the call happens in a `Task` the test cannot await, wait on
the peer:

```swift
try await mock.$fetch.waitForCall()                 // count: 1, deadline: .seconds(1)
try await mock.$fetch.waitForCall(count: 2, deadline: .seconds(2))
```

It throws `MockWaitError` on timeout. It guarantees only that the mocked function ran N
times, not that code after the call site ran. Suspension order across peers is undefined,
so wait on the **last** call in a chain.

Every peer records under a `Mutex`, so read `callCount`, `args`, and `history` from any
task. Never build a latch, an actor, or a semaphore to observe a mock.
