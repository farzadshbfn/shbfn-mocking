---
name: shbfn-mocking
description: Use when a Swift test needs a test double — mocking or stubbing a dependency protocol or struct, faking a service, building a test fixture, controlling what a dependency returns or throws, verifying that a call happened with the right arguments, or waiting on a call from unstructured concurrency. Also use when adding this package to a target, when "type has no member 'Mock'" appears, when a mock traps with "return value not configured", or when a request only says "mock this protocol", "fake this service", or "check it was called". Covers the MOCKING define, @Mockable on protocols, structs, and generics, @MockedMethod and @MockedProperty, standalone Mock.Method and Mock.Property, configuring returns/throws/onCall, isExclusive, and callCount, args, and history.
license: MIT
---

# Mocking

`Mocking` generates test doubles for Swift protocols and structs. When a project depends
on it, mock through this package. Do not hand-roll fakes, and do not add a second mocking
library beside it.

This skill is the full reference. For suite naming, test structure, traits, and async
testing conventions, use the **`shbfn-testing`** skill.

## 1. Integrate the package

Add the dependency:

```swift
.package(url: "https://github.com/farzadshbfn/shbfn-mocking.git", branch: "main"),
```

Add `Mocking` to **every target that uses the macro**, and define `MOCKING` for debug
builds in each one. The production target that declares the type needs both, not only the
test target:

```swift
.target(
    name: "MyFeature",
    dependencies: [.product(name: "Mocking", package: "shbfn-mocking")],
    swiftSettings: [.define("MOCKING", .when(configuration: .debug))]
),
```

The macro puts all generated code inside `#if MOCKING`. Without the define the code still
compiles, but `Type.Mock()` does not exist. Release builds ship no mock code. When
`Type.Mock()` is "not found", check the define first.

Call sites need `import Mocking`.

## 2. Define types with it

Mark the dependency `@Mockable` where it is declared, in the production module.

```swift
enum AuthError: Error {
    case missingToken
}

@Mockable
protocol TokenStoring {
    var clientID: String { get }
    func token() async throws(AuthError) -> String
    func refresh(force: Bool) async
}
```

Prefer typed `throws`. It also types the `.throws` knob, so the test can write
`.throws = .missingToken`. It works on a protocol method and on a witness struct
closure property.

| Spelling | Meaning |
|----------|---------|
| `Type.Mock()` | Controller. Configure and verify through `$` peers |
| `controller.instance` | The value to inject |
| `Type.mock` | Lenient ready instance, no configuration |

A protocol controller conforms to the protocol, so you can inject it directly.

Pick the shape by what you need:

- **Protocol** — for a dependency with behavior. Each method and property gets a `$` peer.
- **Struct with closure properties** — a witness. Each closure behaves like a method.
- **Struct with value properties only** — a fixture. `Type.mock` fills each property from
  that property type's `.mock`, and nested `@Mockable` structs compose automatically.
- **Generic protocol** — bind each `associatedtype` at the call: `Repository.Mock<Entry>()`.
  There is no `.mock`.
- **Hand-written struct you cannot annotate whole** — put `@MockedMethod` or
  `@MockedProperty(.getSet)` on the single member you want to control.
- **A closure or a callback** — build a `Mock.Method` directly. Never invent a protocol
  only to mock it.

### `$` peers

| Member | Peer |
|--------|------|
| `func fetch(id:)` | `mock.$fetch` |
| read-only `var token` | `mock.$token.get` |
| read-write `var title` | `mock.$title.get`, `mock.$title.set` |

Call the public API (`fetch`, `token`). Configure and inspect through the `$` peer.

### Structs

A struct gets the same grammar as a protocol: `Type.Mock()`, `$` peers, `init(mock:)`,
`.instance`, and the lenient `.mock`. Each stored property becomes a peer, by kind:

- **Closure property**. It behaves like a method: `$name.returns`, `.throws`, `.onCall`,
  plus `callCount`, `args`, and `history`.
- **Value property**. It becomes `$name.get`, and is **configure-only**. The mock reads it
  once when `.instance` or `.mock` builds the struct, so `callCount` has no meaning. An
  unconfigured property falls back to the declared default, else to `Type.mock`.

```swift
SampleConfig.mock  // SampleConfig(timeout: 0, label: "")
SampleConfig.Mock().with { $0.$timeout.get.returns = 30 }.instance
```

### Manual `Mockable` conformance

When a property type cannot chain `.mock`, write the conformance by hand:

```swift
extension WidgetID: Mockable {
    static var mock: WidgetID { WidgetID("fixture-default-id") }
}
```

### Hand-written types

`@MockedMethod` and `@MockedProperty` add a `$` peer to one member of a struct you write
yourself.

```swift
struct MockedMethodService {
    @MockedMethod func load(id: Int) -> String
    @MockedMethod func download(id: Int) async throws -> String
}

struct MockedPropertyService {
    @MockedProperty(.get) var label: String
    @MockedProperty(.getSet) var title: String
    @MockedProperty(.getThrows(MockedServiceError.self)) var session: String
}
```

`@MockedMethod` takes no argument. It reads `async` and `throws` from the signature.
`@MockedProperty` takes a kind: `.get`, `.getSet`, `.getAsync`, `.getAsyncSet`,
`.getThrows`, `.getThrowsSet`. The two throwing kinds also take a failure type.

### Generics

Bind the type parameters at `.Mock()`.

- **Generic struct**. Nothing is special: `Box<Int>.Mock()`. A value property of generic
  type with no declared default resolves at runtime. It uses the configured value, else
  the `Mockable` default, else it traps. Non-`Mockable` instantiations still work, but
  their `.mock` traps on that property.
- **Generic protocol**. Each `associatedtype` becomes a `Mock` parameter, in declaration
  order: `Repository.Mock<Entry>()`. There is **no `.mock`**, because nothing can infer it.
- **Primary associated types** cannot be split. List all associated types on `Mock`
  (`Store.Mock<Item, StoreError>()`), not `Store<Item>.Mock<StoreError>()`. Injection
  sites keep the sugar, because the mock satisfies `some Store<Item>`.
- **Generic methods** erase their generic parameters. `args` is `Any`, so cast it
  (`mock.$test.args as? Int == 42`). The call site force-casts the configured return
  value, so `.returns` must hold the type the caller expects.
- **Static requirements plus associated types** are unsupported, and the macro reports a
  diagnostic. A generic type cannot hold static `$` peers.

### Mocking without a type

A `$` peer *is* a `Mock.Method` or a `Mock.Property`. For a single callback or closure
dependency, build one directly.

Pick the variant by shape:

- `Mock.Method<Inputs, Output>.Sync`, `.Async`, `.SyncThrows<Failure>`, `.AsyncThrows<Failure>`
- `Mock.Property<Value>.Get`, `.GetSet`, `.GetAsync`, `.GetAsyncSet`, `.GetThrows<Failure>`,
  `.GetThrowsSet<Failure>`

Invoke it with `result(_:)`, and drop the argument when `Inputs` is `Void`. The
configuration and verification surface is the same.

```swift
let onProgress = Mock.Method<Double, Void>.Sync(subject: "onProgress")
let sut = Downloader(onProgress: { onProgress.result($0) })
sut.run()
#expect(onProgress.history == [0.5, 1.0])
```

The `subject` label is optional. It names the peer in `waitForCall` timeout messages.

## 3. Write tests

The examples use Swift Testing. The package works with XCTest too.

Name the system under test `sut`. Do not name it `loader` or `authService`.

Configure with a **single** `.with { }` per controller, before you build the `sut`. Give a
nested mock its own `.with { }` inside the parent closure. Then follow Given, When, Then.

```swift
@Suite
struct TokenManagerTests {
    @Test
    func refreshesWhenTheStoreHasNoToken() async throws {
        let store = TokenStoring.Mock().with {
            $0.$token.throws = .missingToken
            $0.$refresh.onCall = { _ in }
        }
        let sut = TokenManager(store: store.instance)

        try await sut.ensureToken()

        #expect(store.$refresh.callCount == 1)
    }
}
```

### Configure

| Knob | Effect |
|------|--------|
| `.returns` | Fixed value on every call |
| `.throws` | Throws on every call |
| `.onCall` | Computes the return value from the inputs |

Only one knob is active at a time. When you set one, the others clear.

- Optional returns: `.returns = .some(nil)` returns `nil`. `.returns = nil` *clears* it.
- Properties split into `$name.get` and `$name.set`. Read-only properties have `get` only.
- The mock records setter calls automatically. Use `$name.set.onCall` only for custom
  setter behavior.
- A method that returns `Void` needs no configuration. This includes a method that also
  takes no parameters, such as `func fetch() async`.

#### `isExclusive`

The default is `false`. An unconfigured peer returns the `Mockable` default: `Int` gives
`0`, `String` gives `""`, and an `@Mockable` struct gives its fixture.

Set `isExclusive = true` when such a silent default lets the code continue with a
meaningless value and hides missing setup. Every call must then have a configuration, or
the mock traps.

### Verify

| Member | Meaning |
|--------|---------|
| `$name.callCount` | How many calls the mock recorded |
| `$name.args` | Inputs of the most recent call, `nil` before the first call |
| `$name.history` | Inputs of every call, in order |

For properties, use `mock.$title.get.callCount` and `mock.$title.set.args`.

With two or more parameters, `args` is a labeled tuple (`mock.$fetch.args?.api`). With one
parameter, `args` is the value itself (`mock.$load.args == 42`). For a generic method the
parameters erase, so cast: `mock.$test.args as? Int == 42`.

Assert related fields that always change together in **one** test. Tests run in parallel,
so more tests buy no extra isolation here.

### Async and unstructured concurrency

`Task.sleep`, `Thread.sleep`, `Task.yield()` loops, and polling are the main source of
flaky tests. Do not use them. Use Swift Testing's `confirmation`, and make sure every
`confirm()` runs before the closure returns.

Use this only when you cannot build the test around `confirmation`:

```swift
try await mock.$fetch.waitForCall(count: 1, deadline: .seconds(1))
```

`waitForCall` guarantees only that the mocked function ran N times. It does **not**
guarantee that the code after the call site ran, and the suspension order across peers is
undefined. When you wait on a chain of calls, wait on the **last** call in it.

Never build a latch, an actor, or a semaphore to observe a mock. Every peer records its
calls under a `Mutex`, and `waitForCall` parks a continuation that the next matching call
resumes, so you can read `callCount`, `args`, and `history` from any task.
