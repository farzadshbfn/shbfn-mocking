# Usage reference

Configuring and verifying through `$` peers. Setup (the dependency and the `MOCKING` define) is in the [README](../README.md).

`Type.Mock` is a typealias to the generated peer, so `Type.Mock()` and `TypeMock()` are the same thing. Controllers conform to `MockWithable`; its methods are `@_disfavoredOverload`, so a same-named `with` from your own library wins for types conforming to both. `.with { }` also accepts `async` closures.

## `$` peers

| Member | Peer |
|--------|------|
| `func fetch(id:)` | `mock.$fetch` |
| read-only `var token` | `mock.$token.get` |
| read-write `var title` | `mock.$title.get`, `mock.$title.set` |

Exercise the public API (`fetch`, `token`); configure and inspect through the `$` peer.

## Configuring

| Knob | Effect |
|------|--------|
| `.returns` | Fixed value every call |
| `.throws` | Throw every call |
| `.onCall` | Compute the return from inputs |

Only one is active at a time — setting one clears the others.

- Optional returns: `.returns = .some(nil)` returns `nil`; `.returns = nil` *clears* the configuration.
- Setter calls are recorded automatically; `$name.set.onCall` is only for custom setter behavior.
- Two or more parameters: `args` is a labeled tuple (`mock.$fetch.args?.api`). A single parameter: `args` is the value itself (`mock.$load.args == 42`).

## `isExclusive`

Default `false`: unconfigured peers leniently return `Mockable.mock` defaults (`Int` → `0`, `String` → `""`, `@Mockable` structs, …). Set `true` when those silent defaults would let code proceed with meaningless values and hide missing setup — every call must then be configured, or it traps.

## Verifying

`$name.callCount`, `$name.args` (most recent call), `$name.history` (ordered). For properties: `mock.$title.get.callCount`, `mock.$title.set.args`.

## `@Mockable` on structs

Same grammar as a protocol (`Type.Mock()`, `$` peers, `init(mock:)`, `.instance`, lenient `.mock`). Each stored property becomes a peer by kind:

- **Closure property** — behaves like a method: `$name.returns` / `.throws` / `.onCall`, plus `callCount` / `args` / `history`.
- **Value property** — `$name.get`, **configure-only**: read once when `.instance` / `.mock` builds the struct, so `callCount` is meaningless. Unconfigured falls back to the declared default, else `Type.mock`.

A struct with no closure properties is therefore a fixture: `Type.mock` fills each property from `ThatType.mock`, nested `@Mockable` structs composing automatically.

```swift
SampleConfig.mock                                            // SampleConfig(timeout: 0, label: "")
SampleConfig.Mock().with { $0.$timeout.get.returns = 30 }.instance
```

Write a manual `Mockable` conformance only when a property type cannot chain `.mock` — see `Tests/ForeignNiceTypes.swift`.

## Generics

Bind type parameters at `.Mock()`.

- **Generic struct** — nothing special: `Box<Int>.Mock()`. A generic-typed value with no declared default resolves at runtime (configured → `Mockable` default → trap), so non-`Mockable` instantiations are usable but their `.mock` traps on that property.
- **Generic protocol** — each `associatedtype` becomes a `Mock` parameter in declaration order: `Repository.Mock<Entry>()`. There is **no `.mock`** (nothing to infer from).
- **Primary associated types** cannot be split: list all associated types on `Mock` (`Store.Mock<Item, StoreError>()`), not `Store<Item>.Mock<StoreError>()`. Injection sites still get the sugar — the mock satisfies `some Store<Item>`.
- **Static requirements plus associated types** — unsupported, and diagnosed: a generic type cannot hold static `$` peers.

## Mocking without a protocol

A `$` peer *is* a `Mock.Method` / `Mock.Property`. For a one-off callback, closure dependency, or hand-rolled conformance, construct one directly rather than inventing a protocol to mock. Pick the variant by shape — `Mock.Method<Inputs, Output>.Sync` / `.Async` / `.SyncThrows<Failure>` / `.AsyncThrows<Failure>`, `Mock.Property<Value>.Get` / `.GetSet` / `.GetAsync` — and invoke it with `result(_:)` (no argument for `Void` inputs). Same configuration and verification surface.

```swift
let onProgress = Mock.Method<Double, Void>.Sync(subject: "onProgress")
let sut = Downloader(onProgress: { onProgress.result($0) })
sut.run()
#expect(onProgress.history == [0.5, 1.0])
```

## Waiting on unstructured concurrency

`Task.sleep`, `Thread.sleep`, `Task.yield()` loops, and polling make tests flake. Prefer Swift Testing's `confirmation`. Last resort, when the test cannot be structured around it:

```swift
try await mock.$fetch.waitForCall(count: 1, deadline: .seconds(1))
```

`waitForCall` only guarantees the mocked function was *invoked* N times — **not** that code after the call site in the callee has run, and suspension order across peers is undefined. When waiting on a chain, wait on the **last** call in it. See `Tests/MockWaitForCallTests.swift`.

## Examples

- `Tests/MockingTests.swift` — `Macros`, `Witness structs`, `Generic mocks` suites
- `Tests/MockWaitForCallTests.swift` — standalone `Mock.Method` / `Mock.Property`, `waitForCall`
- `Tests/MockingMacrosTests/` — expansion output per shape
