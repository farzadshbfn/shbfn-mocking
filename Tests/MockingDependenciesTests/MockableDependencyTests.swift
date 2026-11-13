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
}

// A macro cannot add this accessor, so a consumer that wants a key path writes it.
extension DependencyValues {
    var authorizationTokenManager: any Authorization.TokenManager {
        get { self[Authorization.TokenManagerKey.self] }
        set { self[Authorization.TokenManagerKey.self] = newValue }
    }
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
    func `the live context resolves the live value through the key type`() {
        @Dependency(Authorization.TokenManagerKey.self) var tokenManager

        #expect(tokenManager.count() == 7)
    }
}
#endif
