# Mocking

Test doubles for Swift protocols and structs. The `@Mockable` macro generates them.

```swift
@Mockable
protocol Greeter {
    func greet(name: String) -> String
}

let mock = Greeter.Mock().with {
    $0.$greet.returns = "hi"
}

#expect(mock.greet(name: "x") == "hi")
#expect(mock.$greet.callCount == 1)
```

## Agent skills

The full reference lives in the [shbfn-mocking skill](skills/shbfn-mocking/SKILL.md). The
[shbfn-testing skill](skills/shbfn-testing/SKILL.md) carries the Swift testing conventions
around it.

```bash
gh skill install farzadshbfn/shbfn-mocking shbfn-mocking
gh skill install farzadshbfn/shbfn-mocking shbfn-testing
```

## Install

Add the package:

```swift
.package(url: "https://github.com/farzadshbfn/shbfn-mocking.git", branch: "main"),
```

Then depend on `Mocking` in **every target that uses the macro**. This includes the
production target that declares the type, not only the test target. Define `MOCKING`
for debug builds in each of those targets:

```swift
.target(
    name: "MyFeature",
    dependencies: [.product(name: "Mocking", package: "shbfn-mocking")],
    swiftSettings: [.define("MOCKING", .when(configuration: .debug))]
),
.testTarget(
    name: "MyFeatureTests",
    dependencies: ["MyFeature", .product(name: "Mocking", package: "shbfn-mocking")],
    swiftSettings: [.define("MOCKING", .when(configuration: .debug))]
),
```

The define is required. The macro puts all generated mock code inside `#if MOCKING`.
Without the define your code still compiles, but `Type.Mock()` does not exist. Release
builds ship no mock code.

## Usage

Mark a protocol or a struct `@Mockable`. The macro generates three spellings:

| Spelling | Meaning |
|----------|---------|
| `Type.Mock()` | Controller. Configure and verify through `$` peers |
| `controller.instance` | The value to inject |
| `Type.mock` | Lenient ready instance, no configuration |

A protocol controller conforms to the protocol, so you can pass it directly.

Configure with a single `.with { }` per controller, before you build the system under
test. Then follow Given, When, Then:

```swift
enum AuthError: Error {
    case missingToken
}

@Mockable
protocol TokenStore {
    func token() async throws(AuthError) -> String
    func refresh(force: Bool) async
}
```

```swift
let store = TokenStore.Mock().with {
    $0.$token.throws = .missingToken
    $0.$refresh.onCall = { _ in }
}
let sut = TokenManager(store: store.instance)

try await sut.ensureToken()

#expect(store.$refresh.callCount == 1)
```

A typed `throws` also types the `throws` knob, so dot syntax works.

## `$` peers

| Member | Peer |
|--------|------|
| `func fetch(id:)` | `mock.$fetch` |
| read-only `var token` | `mock.$token.get` |
| read-write `var title` | `mock.$title.get`, `mock.$title.set` |

Call the public API (`fetch`, `token`). Configure and inspect through the `$` peer.

## Configuring

| Knob | Effect |
|------|--------|
| `.returns` | Fixed value on every call |
| `.throws` | Throws on every call |
| `.onCall` | Computes the return value from the inputs |

Only one knob is active at a time. When you set one, the others clear.

- Optional returns: `.returns = .some(nil)` returns `nil`. `.returns = nil` *clears* the
  configuration.
- The mock records setter calls automatically. Use `$name.set.onCall` only for custom
  setter behavior.
- With two or more parameters, `args` is a labeled tuple (`mock.$fetch.args?.api`).
  With one parameter, `args` is the value itself (`mock.$load.args == 42`).

## `isExclusive`

The default is `false`. Unconfigured peers return `Mockable` defaults: `Int` gives `0`,
`String` gives `""`, and `@Mockable` structs give their fixture.

Set `isExclusive = true` when such a silent default lets your code continue with a
meaningless value and hides missing setup. Every call must then have a configuration,
or the mock traps.

## Verifying

| Member | Meaning |
|--------|---------|
| `$name.callCount` | How many calls the mock recorded |
| `$name.args` | Inputs of the most recent call, `nil` before the first call |
| `$name.history` | Inputs of every call, in order |

For properties, use `mock.$title.get.callCount` and `mock.$title.set.args`.

## `@Mockable` on structs

A struct gets the same grammar as a protocol: `Type.Mock()`, `$` peers, `init(mock:)`,
`.instance`, and the lenient `.mock`. Each stored property becomes a peer, by kind:

- **Closure property**. It behaves like a method: `$name.returns`, `.throws`, `.onCall`,
  plus `callCount`, `args`, and `history`.
- **Value property**. It becomes `$name.get`, and is **configure-only**. The mock reads it
  once when `.instance` or `.mock` builds the struct, so `callCount` has no meaning. An
  unconfigured property falls back to the declared default, else to `Type.mock`.

A struct with no closure property is therefore a fixture. `Type.mock` fills each property
from that property type's `.mock`, and nested `@Mockable` structs compose automatically.

```swift
SampleConfig.mock  // SampleConfig(timeout: 0, label: "")
SampleConfig.Mock().with { $0.$timeout.get.returns = 30 }.instance
```

Write a manual `Mockable` conformance only when a property type cannot chain `.mock`.

## Mocking a hand-written type

`@MockedMethod` and `@MockedProperty` add a `$` peer to one member of a struct you write
yourself. Use them when the type is not a protocol and not `@Mockable`.

```swift
struct MockedMethodService {
    @MockedMethod func load(id: Int) -> String
    @MockedMethod func download(id: Int) async throws -> String
}

struct MockedPropertyService {
    @MockedProperty(.get) var label: String
    @MockedProperty(.getSet) var title: String
    @MockedProperty(.getThrows(MockedServiceError.self)) var session: String
    @MockedProperty(.getAsyncThrows(MockedServiceError.self)) var receipt: String
}
```

A kind matches the accessor shape: `.get`, `.getSet`, `.getAsync`, `.getAsyncSet`,
`.getThrows`, `.getThrowsSet`, and `.getAsyncThrows`. On an `@Mockable` protocol the macro
reads the shape from the requirement, so `var token: String { get async throws }` needs no
attribute.

### Naming a peer

A peer takes the member's name, so two members can claim one peer name. Use `named:` to
give one of them its own peer. Your own declaration stays as it is. The collision
diagnostic carries a fix-it that adds the attribute for you.

```swift
@Mockable
protocol Worker {
    func run()
    @MockedMethod(named: "runForce")
    func run(force: Bool)
}

let mock = Worker.Mock()
mock.run(force: true)
#expect(mock.$runForce.callCount == 1)
```

`named:` takes a string literal. It works on `@MockedMethod` and on `@MockedProperty`, both
on a hand-written type and on a member of an `@Mockable` protocol. The member's own
attribute always wins over the generated one.

## Waiting on unstructured concurrency

`Task.sleep`, `Thread.sleep`, `Task.yield()` loops, and polling make tests flake. Prefer
Swift Testing's `confirmation`. Use this only as a last resort:

```swift
try await mock.$fetch.waitForCall(count: 1, deadline: .seconds(1))
```

`waitForCall` guarantees only that the mocked function ran N times. It does **not**
guarantee that the code after the call site ran, and the suspension order across peers is
undefined. When you wait on a chain of calls, wait on the **last** call in it.

## Examples

- `Tests/MockingTests.swift` — the `Macros`, `Witness structs`, `Generic mocks`, and
  `Mockable Generic Methods` suites
- `Tests/MockWaitForCallTests.swift` — standalone `Mock.Method` and `Mock.Property`,
  and `waitForCall`
- `Tests/ForeignNiceTypes.swift` — manual `Mockable` conformances
- `Tests/MockingMacrosTests/` — the expansion output for each shape
