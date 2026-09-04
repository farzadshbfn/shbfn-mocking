---
name: shbfn-testing
description: Use when writing, reviewing, or fixing a Swift test — naming a suite or test, structuring it around a sut, Swift Testing vs XCTest, a flaky or hanging async test, parallel-safe shared state, or shared setup through a TestScoping trait. Also use when a test reaches for Task.sleep or polling, when tests pass alone but fail together, or when a request only says "write a unit test" or "add coverage".
license: MIT
---

# Testing

Swift Testing is the default. Use XCTest only where the target requires it, such as a UI
test target. Do not add new XCTest unit tests beside a Swift Testing suite.

To mock a dependency, use the **`shbfn-mocking`** skill.

## Naming

Name suites and tests with raw identifiers (backticks). The identifier *is* the display
name, so never pass a `@Suite("…")` or `@Test("…")` string. Keep the parentheses for
traits only.

- **Suite** — a `Title Case` noun phrase, no `Tests` suffix: `` `Profile Loader` ``.
- **Test** — lowercase, `<expected> when <condition>`. Drop `when` when there is no
  condition.

A suite is a real type. `` struct `TokenStore` `` shadows the `TokenStore` under test, so
spell multi-word names out; a name with a space can never collide.

Name the system under test `sut`, never `loader` or `authService`.

## Structure

Follow Given, When, Then. Build the world, run one action, then assert.

```swift
@Suite
struct `Token Manager` {
    @Test
    func `refreshes the token when the store has none`() async throws {
        let store = TokenStoring.Mock().with {
            $0.$token.throws = .missingToken
        }
        let sut = TokenManager(store: store.instance)

        try await sut.ensureToken()

        #expect(store.$refresh.callCount == 1)
    }
}
```

- Assert fields that always change together in **one** test. Tests run in parallel, so
  more tests buy no extra isolation.
- Extract pure logic (calculations, parsing, transforms) into a function and test it
  before you debug behavior visually.
- Prefer exact assertions. Compare floating-point values against an epsilon, not `==`.

## Async

`Task.sleep`, `Thread.sleep`, `Task.yield()` loops, and polling cause flaky tests. Do not
use them. Use `confirmation`, and make sure every `confirm()` runs before the closure
returns:

```swift
await confirmation("delivers both events", expectedCount: 2) { confirm in
    sut.onEvent = { _ in confirm() }
    await sut.run()
}
```

When a mock stands in for the dependency, wait on the call with `waitForCall` from the
**`shbfn-mocking`** skill. Never write a coordination type for a test: no custom actor,
latch, semaphore, or `CheckedContinuation` box. A mock already synchronizes itself.

## Shared mutable state

Tests share one process and run in parallel. Make the state safe first, then reach for
`.serialized`.

Guard a value the test owns with a `Mutex` from `Synchronization`:

```swift
let received = Mutex<[Event]>([])
sut.onEvent = { event in received.withLock { $0.append(event) } }

await sut.run()

#expect(received.withLock { $0 } == [.started, .finished])
```

Use `.serialized` only when you cannot make the state safe: a bootstrapped metrics
backend, a singleton you do not own, a shared file, a process-wide environment variable.
It costs time and hides the race rather than removing it.

## Scoping traits

For plain unit tests, skip custom traits. An `init` and `let sut = …` are enough.

Write a `TestScoping` trait instead of a `withFoo { }` wrapper when several tests share
setup and teardown with a lifecycle: a server, a database, a temp folder. Not for one-off
setup or a helper with no lifecycle. Your repo may document its own traits; reuse them.

- **`isRecursive: true`** when each test needs a fresh environment. A non-recursive suite
  trait scopes once per suite and silently shares state.
- **Macro-safe overloads**: expose the zero-argument form as `static var withFoo`, and a
  separate `static func` overload. A default parameter on a `static func` can break trait
  macro expansion.
- **Tear down inside the scope.** Background work or open connections left running crash
  parallel tests on deinit.
- Task-local context types must be `Sendable`, often `@unchecked Sendable` in tests.
