---
name: shbfn-testing
description: Use when writing, reviewing, or fixing a Swift test — naming a suite or a test, structuring one around a system under test, choosing between Swift Testing and XCTest, chasing a flaky or hanging async test, testing unstructured concurrency, making tests that share mutable state safe to run in parallel, or sharing setup and teardown across a suite. Also use when a test reaches for Task.sleep or polling, when tests pass alone but fail together, or when a request only says "write a unit test", "this test is flaky", or "add coverage". Covers backtick raw-identifier naming, the sut rule, Given/When/Then, exact assertions over visual checks, confirmation, a Mutex against .serialized, and custom TestScoping traits.
license: MIT
---

# Testing

Swift Testing is the default for unit tests. Use XCTest only where the target requires
it, such as a UI test target. Do not add new XCTest unit tests beside a Swift Testing
suite.

To mock a dependency, use the **`shbfn-mocking`** skill.

## Naming

Name suites and tests with raw identifiers (backticks). The identifier *is* the display
name, so never pass a `@Suite("…")` or `@Test("…")` string. Keep the parentheses for
traits only.

- **Suite** — a `Title Case` noun phrase, with no `Tests` suffix: `` `Profile Loader` ``.
- **Test** — lowercase, `<expected> when <condition>`. Drop the `when` clause when there
  is no condition.

A suite is a real type, so spell multi-word names out. `` struct `TokenStore` `` shadows
the `TokenStore` under test and breaks every reference inside the suite. A raw identifier
that holds a space or a dot can never collide.

Name the system under test `sut`. Do not name it `loader` or `authService`. A reader then
sees which value the test exercises, and which values only support it.

## Structure

Follow Given, When, Then. Build the world, run one action, then assert.

```swift
@Suite
struct `Token Manager` {
    @Test
    func `refreshes the token when the store has none`() async throws {
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

Assert related fields that always change together in **one** test. Tests run in parallel,
so more tests buy no extra isolation here.

Extract pure logic — calculations, parsing, data transforms — into a function you can
test. Test that function before you debug the behavior visually.

Prefer exact assertions over a "looks right" check. Compare floating-point values against
an epsilon, not with `==`.

## Async and unstructured concurrency

`Task.sleep`, `Thread.sleep`, `Task.yield()` loops, and polling are the main source of
flaky tests. Do not use them.

Use `confirmation`, which replaces `XCTestExpectation`. Make sure every `confirm()` runs
before the closure returns.

```swift
await confirmation("delivers both events", expectedCount: 2) { confirm in
    sut.onEvent = { _ in confirm() }
    await sut.run()
}
```

When a mock stands in for the dependency, wait on the call itself with `waitForCall`,
never with a latch or an actor you wrote for the test. See the **`shbfn-mocking`** skill
for `waitForCall` and its guarantees.

## Shared mutable state

Tests run in parallel and share one process, so shared mutable state races. Make the
state safe first, and reach for `.serialized` second.

Guard the state with a `Mutex` from `Synchronization`, and let the tests stay parallel.
`Mutex` protects the value itself, so the code under test is safe in production too, not
only under the test runner.

**Never write a coordination type for a test.** No custom actor, no latch, no semaphore,
and no hand-rolled `CheckedContinuation` box to watch a dependency. A mock from the
**`shbfn-mocking`** skill already synchronizes itself: it records every call under a
`Mutex`, and `waitForCall` parks a continuation that the next matching call resumes. Read
`callCount`, `args`, and `history` from any task, and wait with `waitForCall`. A
hand-rolled latch rebuilds that machinery and gets the edge cases wrong.

A `Mutex` is for a value the test itself owns, such as events a closure collects. It is
not the tool for waiting on a dependency.

```swift
let received = Mutex<[Event]>([])
sut.onEvent = { event in received.withLock { $0.append(event) } }

await sut.run()

#expect(received.withLock { $0 } == [.started, .finished])
```

Use `.serialized` when you cannot make the state safe: a bootstrapped metrics backend, a
singleton you do not own, a shared file, or a process-wide environment variable. It
serializes the suite, so it costs time, and it hides the race rather than removing it.

## Custom scoping traits

For plain unit tests, skip custom traits. An `init` and `let sut = …` are enough.

Write a `TestScoping` trait instead of a hand-rolled `withFoo { }` wrapper when several
tests share the same setup and teardown, such as a server, a database, or a temp folder.
Do not write one for one-off setup, or for a helper that has no lifecycle, such as a
request builder or an encoder.

Split traits by responsibility, then compose them left to right, in nesting order
(`@Suite(.withServerApp, .withServerClient)`):

| Layer | Owns |
|-------|------|
| Resource | Expensive or shared backing state: a database, an app, a temp directory |
| Session | A narrower runtime on top: an HTTP client, a transaction, a mock clock |

A dependent trait may build a default resource when none exists. It must **reuse** the
one an outer trait installed, and never replace a parent-configured instance.

Pitfalls:

- **Use `isRecursive: true`** when each test needs a fresh environment. A non-recursive
  suite trait scopes once per suite, and silently shares state across tests.
- **Keep the overloads macro-safe.** Expose the zero-argument form as `static var
  withFoo`, and add a separate `static func` overload. A default parameter on a `static
  func` can break trait macro expansion.
- **Name private helpers differently from the trait** (`runWithServerApp` against
  `.withServerApp`), so they do not collide.
- **Tear down before you release.** When setup starts background work or holds
  connections, shut it down inside the scope. Otherwise parallel tests crash on deinit.
- Task-local context types must be `Sendable`, and often `@unchecked Sendable` in tests.
