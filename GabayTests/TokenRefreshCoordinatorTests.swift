//
//  TokenRefreshCoordinatorTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

// A refresher that counts calls and returns a fixed result, for tests that
// don't need to control timing.
private actor StubTokenRefresher: TokenRefreshing {

    private(set) var callCount = 0
    private let result: Result<AuthTokens, APIError>

    init(result: Result<AuthTokens, APIError>) {
        self.result = result
    }

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        callCount += 1
        return try result.get()
    }
}

// A refresher whose `refresh` suspends until the test opens the gate, so
// concurrent callers can be made to genuinely overlap inside it instead of
// completing one after another.
private actor GatedTokenRefresher: TokenRefreshing {

    private(set) var callCount = 0
    private let tokens: AuthTokens
    private var isOpen = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var gateWaiters: [CheckedContinuation<Void, Never>] = []

    init(tokens: AuthTokens) {
        self.tokens = tokens
    }

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        callCount += 1
        for waiter in entryWaiters { waiter.resume() }
        entryWaiters = []

        if !isOpen {
            await withCheckedContinuation { continuation in
                gateWaiters.append(continuation)
            }
        }
        return tokens
    }

    /// Suspends until `refresh(using:)` has been entered at least once.
    func waitForEntry() async {
        if callCount > 0 { return }
        await withCheckedContinuation { continuation in
            entryWaiters.append(continuation)
        }
    }

    func openGate() {
        isOpen = true
        for waiter in gateWaiters { waiter.resume() }
        gateWaiters = []
    }
}

extension SharedStubProtocolSuite {

@Suite(.serialized)
struct LiveTokenRefresherTests {

    private let base = URL(string: "https://example.test/api")!

    private func makeRefresher() -> LiveTokenRefresher {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        let api = URLSessionAPIClient(
            baseURL: base,
            session: URLSession(configuration: configuration),
            retryPolicy: .none
        )
        return LiveTokenRefresher(api: api)
    }

    // Would fail if `refresh(using:)` still decoded the response as
    // `AuthResult`: the contract payload for `/auth/refresh` has no `role`
    // key, so that decode throws `keyNotFound` and this test would fail
    // with a decoding error instead of returning tokens.
    @Test func decodesTheContractShapeWithNoRoleKey() async throws {
        let refresher = makeRefresher()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("""
            {
                "accessToken": "renewed-access-token",
                "refreshToken": "renewed-refresh-token",
                "expiresAt": "2026-09-25T00:00:00Z"
            }
            """.utf8)
        ))

        let tokens = try await refresher.refresh(using: "refresh1")

        #expect(tokens.accessToken == "renewed-access-token")
        #expect(tokens.refreshToken == "renewed-refresh-token")
        #expect(tokens.expiresAt == ISO8601DateFormatter().date(from: "2026-09-25T00:00:00Z"))
    }
}
}

@MainActor
struct TokenRefreshCoordinatorTests {

    private func makeSignedInSession() async throws -> Session {
        let auth = StubAuthenticating()
        auth.loginResult = .success(
            AuthResult(accessToken: "abc123", refreshToken: "refresh1", expiresAt: nil, role: .hiker)
        )
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        let session = Session(auth: auth, tokenStore: InMemoryTokenStore())
        try await session.login(email: "hiker@example.test", password: "secret123")
        return session
    }

    // Would fail if the coordinator tried to refresh with no current tokens
    // instead of short-circuiting to `.unauthorized()`.
    @Test func refreshWithNoStoredTokensThrowsUnauthorized() async {
        let store = InMemoryTokenStore()
        let refresher = StubTokenRefresher(result: .failure(.server(status: 500)))
        let link = SessionLink()
        let coordinator = TokenRefreshCoordinator(store: store, refresher: refresher, link: link)

        await #expect(throws: APIError.unauthorized()) {
            try await coordinator.refresh(staleAccessToken: "abc123")
        }
        #expect(await refresher.callCount == 0)
    }

    // Would fail if the coordinator called the refresher with an empty
    // refresh token instead of recognizing there is nothing to refresh
    // with, and would fail if it left the session signed in afterward.
    @Test func refreshWithNoRefreshTokenThrowsUnauthorizedAndInvalidates() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "abc123", refreshToken: nil))
        let refresher = StubTokenRefresher(result: .failure(.server(status: 500)))
        let session = try await makeSignedInSession()
        let link = SessionLink()
        link.session = session
        let coordinator = TokenRefreshCoordinator(store: store, refresher: refresher, link: link)

        await #expect(throws: APIError.unauthorized()) {
            try await coordinator.refresh(staleAccessToken: "abc123")
        }
        #expect(await refresher.callCount == 0)
        #expect(await store.load() == nil)
        #expect(session.isSignedIn == false)
    }

    // Would fail if the renewed tokens were returned but never persisted, or
    // if the wrong tokens were returned to the caller.
    @Test func successfulRefreshSavesAndReturnsTheRenewedTokens() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "abc123", refreshToken: "refresh1"))
        let renewed = AuthTokens(accessToken: "renewed456", refreshToken: "refresh2")
        let refresher = StubTokenRefresher(result: .success(renewed))
        let link = SessionLink()
        let coordinator = TokenRefreshCoordinator(store: store, refresher: refresher, link: link)

        let result = try await coordinator.refresh(staleAccessToken: "abc123")

        #expect(result == renewed)
        #expect(await store.load() == renewed)
    }

    // Would fail if every concurrent caller triggered its own refresh
    // instead of sharing one in-flight task: the refresher suspends until
    // released, so a coordinator that doesn't single-flight would show more
    // than one call while the callers are still pending, not just after they
    // all finish.
    @Test func concurrentRefreshesSingleFlight() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "abc123", refreshToken: "refresh1"))
        let renewed = AuthTokens(accessToken: "renewed456", refreshToken: "refresh2")
        let refresher = GatedTokenRefresher(tokens: renewed)
        let link = SessionLink()
        let coordinator = TokenRefreshCoordinator(store: store, refresher: refresher, link: link)

        async let first = coordinator.refresh(staleAccessToken: "abc123")
        async let second = coordinator.refresh(staleAccessToken: "abc123")
        async let third = coordinator.refresh(staleAccessToken: "abc123")

        await refresher.waitForEntry()
        #expect(await refresher.callCount == 1)

        await refresher.openGate()

        let results = try await [first, second, third]

        #expect(results == [renewed, renewed, renewed])
        #expect(await refresher.callCount == 1)
    }

    // Would fail if the coordinator called the refresher again for a token
    // that has already been renewed by someone else, instead of noticing
    // the store no longer matches what the caller thought was stale.
    @Test func staleTokenShortCircuitReturnsStoredTokensWithoutRefreshing() async throws {
        let current = AuthTokens(accessToken: "already-renewed", refreshToken: "refresh1")
        let store = InMemoryTokenStore(tokens: current)
        let refresher = StubTokenRefresher(result: .failure(.server(status: 500)))
        let link = SessionLink()
        let coordinator = TokenRefreshCoordinator(store: store, refresher: refresher, link: link)

        let result = try await coordinator.refresh(staleAccessToken: "stale-access-token")

        #expect(result == current)
        #expect(await refresher.callCount == 0)
    }

    // Would fail if a failed refresh left the session signed in, or threw
    // something other than `.unauthorized()`.
    @Test func failedRefreshInvalidatesAndThrowsUnauthorized() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "abc123", refreshToken: "refresh1"))
        let refresher = StubTokenRefresher(result: .failure(.server(status: 500)))
        let session = try await makeSignedInSession()
        let link = SessionLink()
        link.session = session
        let coordinator = TokenRefreshCoordinator(store: store, refresher: refresher, link: link)

        await #expect(throws: APIError.unauthorized()) {
            try await coordinator.refresh(staleAccessToken: "abc123")
        }
        #expect(await store.load() == nil)
        #expect(session.isSignedIn == false)
    }

    // Would fail if a cancelled refresh signed the session out, which would
    // wrongly treat "the app cancelled this request" as "this token is no
    // longer valid".
    @Test func cancelledRefreshThrowsCancelledWithoutInvalidating() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "abc123", refreshToken: "refresh1"))
        let refresher = StubTokenRefresher(result: .failure(.cancelled))
        let session = try await makeSignedInSession()
        let link = SessionLink()
        link.session = session
        let coordinator = TokenRefreshCoordinator(store: store, refresher: refresher, link: link)

        await #expect(throws: APIError.cancelled) {
            try await coordinator.refresh(staleAccessToken: "abc123")
        }
        #expect(await store.load() != nil)
        #expect(session.isSignedIn == true)
    }
}
