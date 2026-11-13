//
//  Copyright © 2026 SHBFN. All rights reserved.
//  See LICENSE in the project root for full details.
//

#if Dependencies
import Dependencies
import DependenciesTestSupport
import Mocking
import Testing

enum Authorization {}

extension Authorization {
    struct Token: Equatable, Sendable, Mockable {
        let value: String
        static var mock: Token { Token(value: "") }
    }

    enum Failure: Error, Equatable, Mockable {
        case offline
        case rejected
        static var mock: Failure { .rejected }
    }

    @MockableDependency
    protocol TokenManager: Sendable {
        var validToken: Token? { get async throws(Failure) }
        func refresh(_ rejected: Token) async throws(Failure) -> Token
        func signOut() async throws
        func count() -> Int
        func account() async throws(Failure) -> Account
        func profile() async throws -> Account
    }

    /// Has no lenient value, so an unset call must throw.
    struct Account: Equatable, Sendable {
        let id: Int
    }
}

extension Authorization {
    /// A struct dependency: each behaviour is an instance, not a conforming type.
    /// A top-level `Session` exists too, so the generated mock must name this one in full.
    @MockableDependency
    struct Session: Sendable {
        var userID: @Sendable () -> Int
        var refresh: @Sendable (_ token: Token) async throws(Failure) -> Token
    }
}

extension Authorization.SessionKey: DependencyKey {
    static let liveValue = Authorization.Session(userID: { 42 }, refresh: { _ in Authorization.Token(value: "live") })
}

/// A production-like value, added the way a live module would add it.
struct LiveTokenManager: Authorization.TokenManager {
    var validToken: Authorization.Token? { get async throws(Authorization.Failure) { .init(value: "live") } }
    func refresh(_ rejected: Authorization.Token) async throws(Authorization.Failure) -> Authorization.Token {
        .init(value: "fresh")
    }
    func signOut() async throws {}
    func count() -> Int { 7 }
    func account() async throws(Authorization.Failure) -> Authorization.Account { .init(id: 1) }
    func profile() async throws -> Authorization.Account { .init(id: 1) }
}

extension Authorization.TokenManagerKey: DependencyKey {
    static let liveValue: any Authorization.TokenManager = LiveTokenManager()
    static var previewValue: any Authorization.TokenManager {
        Authorization.TokenManager.Mock().with { $0.$count.returns = 3 }
    }
}

/// A key that is its own value, the way a `@DependencyClient` is.
struct Greeting: TestDependencyKey, Equatable {
    var text: String
    static let testValue = Greeting(text: "test")
}

/// A hand-written key whose value type does not lead to it.
enum FarewellKey: TestDependencyKey {
    static let testValue = Greeting(text: "bye")
}

extension DependencyValues {
    @DependencyEntry var authorizationTokenManager: any Authorization.TokenManager
    @DependencyEntry(Greeting.self) var greeting: Greeting
    @DependencyEntry var authorizationSession: Authorization.Session
    // A macro argument cannot name a key that another macro generates, so this form is for hand-written keys.
    @DependencyEntry(FarewellKey.self) var farewell: Greeting
}

/// Reads the dependency the way production code does.
struct Session {
    @Dependency(\.authorizationTokenManager) var tokenManager

    func refreshedToken() async throws(Authorization.Failure) -> Authorization.Token {
        try await tokenManager.refresh(.init(value: "old"))
    }
}

@Suite(.dependencies)
struct `MockableDependency` {
    @Test
    func `an override answers with its configured value and records the call`() async throws {
        let mock = Authorization.TokenManager.Mock()
        mock.$refresh.returns = .init(value: "new")

        let token = try await withDependencies {
            $0.authorizationTokenManager = mock
        } operation: {
            try await Session().refreshedToken()
        }

        #expect(token == .init(value: "new"))
        #expect(mock.$refresh.args == .init(value: "old"))
    }

    @Test
    func `a typed failure reaches the caller as its own type`() async {
        let mock = Authorization.TokenManager.Mock()
        mock.$refresh.throws = .offline

        await withDependencies {
            $0.authorizationTokenManager = mock
        } operation: {
            await #expect(throws: Authorization.Failure.offline) {
                try await Session().refreshedToken()
            }
        }
    }

    @Test
    func `the test value reports an unset call and falls back to the lenient default`() async throws {
        @Dependency(\.authorizationTokenManager) var tokenManager

        try await withKnownIssue {
            #expect(tokenManager.count() == 0)
            let token = try await tokenManager.refresh(.init(value: "old"))
            #expect(token == .mock)
        }
    }

    @Test
    func `the test value reports an unset property and returns its lenient default`() async throws {
        @Dependency(\.authorizationTokenManager) var tokenManager

        try await withKnownIssue {
            let token = try await tokenManager.validToken
            #expect(token == nil)
        }
    }

    @Test
    func `the test value throws the mock error of a typed throw that has no lenient value`() async {
        @Dependency(\.authorizationTokenManager) var tokenManager

        await withKnownIssue {
            await #expect(throws: Authorization.Failure.rejected) {
                try await tokenManager.account()
            }
        }
    }

    @Test
    func `the test value throws an unconfigured error for an untyped throw that has no lenient value`() async {
        @Dependency(\.authorizationTokenManager) var tokenManager

        await withKnownIssue {
            await #expect(throws: UnconfiguredCall.self) {
                try await tokenManager.profile()
            }
        }
    }

    @Test
    func `a lenient mock that the test builds itself stays silent`() async throws {
        let mock = Authorization.TokenManager.Mock()

        let count = withDependencies { $0.authorizationTokenManager = mock } operation: {
            Session().tokenManager.count()
        }

        #expect(count == 0)
    }

    @Test(.dependency(\.context, .live))
    func `the live context resolves the live value through the Key alias`() {
        @Dependency(Authorization.TokenManager.Key.self) var tokenManager

        #expect(tokenManager.count() == 7)
    }

    @Test(.dependency(\.context, .preview))
    func `a preview value in an extension of the generated key wins in the preview context`() {
        @Dependency(\.authorizationTokenManager) var tokenManager

        #expect(tokenManager.count() == 3)
    }

    @Test
    func `an entry with an explicit key reads that key`() {
        @Dependency(\.farewell) var farewell

        #expect(farewell == Greeting(text: "bye"))
    }

    @Test
    func `an entry for a type that is its own key reads and writes that key`() {
        let greeting = withDependencies {
            $0.greeting = Greeting(text: "override")
        } operation: {
            @Dependency(\.greeting) var greeting
            return greeting
        }

        #expect(greeting == Greeting(text: "override"))
    }

    @Test
    func `a struct dependency answers through its mock and records the call`() async throws {
        let mock = Authorization.Session.Mock()
        mock.$refresh.returns = .init(value: "new")

        let token = try await withDependencies {
            $0.authorizationSession = mock.instance
        } operation: {
            @Dependency(\.authorizationSession) var session
            return try await session.refresh(.init(value: "old"))
        }

        #expect(token == .init(value: "new"))
        #expect(mock.$refresh.args == .init(value: "old"))
    }

    @Test
    func `a struct dependency's test value reports unset calls and keeps typed throws`() async {
        @Dependency(\.authorizationSession) var session

        await withKnownIssue {
            #expect(session.userID() == 0)
            await #expect(throws: Authorization.Failure.rejected) {
                try await session.refresh(.init(value: "old"))
            }
        }
    }

    @Test(.dependency(\.context, .live))
    func `a struct dependency's live context resolves the live value`() {
        @Dependency(\.authorizationSession) var session

        #expect(session.userID() == 42)
    }
}
#endif
