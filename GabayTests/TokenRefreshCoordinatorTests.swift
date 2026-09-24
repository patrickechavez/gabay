//
//  TokenRefreshCoordinatorTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

// A refresher that counts calls and returns a fixed result, for tests that don't need to control timing.
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

// A refresher whose `refresh` suspends until the test opens the gate, so concurrent callers genuinely overlap instead of completing one after another.
private actor GatedTokenRefresher: TokenRefreshing {

    private(set) var callCount = 0
    private let tokens: AuthTokens
    private var isOpen = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var gateWaiters: [CheckedContinuation<Void, Never>] = []

    // Tracks callers reaching `coordinator.refresh`, not `refresh(using:)` itself, since a correctly single-flighted follower never reaches this actor at all.
    private var callersArrived = 0
    private var callerWaiters: [(threshold: Int, continuation: CheckedContinuation<Void, Never>)] = []

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

    /// Called by a test caller immediately before it calls into the coordinator, so `waitForCallers(_:)` can tell arrival from scheduling.
    func callerArrived() {
        callersArrived += 1
        let ready = callerWaiters.filter { callersArrived >= $0.threshold }
        callerWaiters.removeAll { callersArrived >= $0.threshold }
        for waiter in ready { waiter.continuation.resume() }
    }

    /// Suspends until `count` callers have reached `callerArrived()`.
    func waitForCallers(_ count: Int) async {
        if callersArrived >= count { return }
        await withCheckedContinuation { continuation in
            callerWaiters.append((count, continuation))
        }
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

    // Would fail if `refresh(using:)` still decoded as `AuthResult`; `/auth/refresh`'s payload has no `role` key, so that decode would throw `keyNotFound`.
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

    // Would fail if the coordinator tried to refresh with no current tokens instead of short-circuiting to `.unauthorized()`.
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

    // Would fail if the coordinator called the refresher with an empty token instead of recognizing there's nothing to refresh with, or left the session signed in.
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

    // Would fail if the renewed tokens were returned but never persisted, or the wrong tokens were returned to the caller.
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

    // Would fail if every caller triggered its own refresh instead of sharing one in-flight task: the refresher suspends until released, so an un-single-flighted coordinator would show more than one call while callers are still pending.
    //
    // Each caller marks arrival via `callerArrived()` before calling the coordinator, and the test waits for all three marks before checking `callCount`; the old version of this test only confirmed the leader reached the refresher, so `callCount == 1` held trivially even when single-flighting was broken.
    //
    // Waiting for all arrivals, then yielding, lets the coordinator's brief await-free `inFlight` check run for each caller, so the mid-flight assertion tests the in-progress state, not just the eventual one. It still leans on the cooperative executor running that step promptly after resumption, which is not a language-level guarantee; the assertion after all three results are collected has no such dependency and is the fully deterministic half of this test.
    @Test func concurrentRefreshesSingleFlight() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "abc123", refreshToken: "refresh1"))
        let renewed = AuthTokens(accessToken: "renewed456", refreshToken: "refresh2")
        let refresher = GatedTokenRefresher(tokens: renewed)
        let link = SessionLink()
        let coordinator = TokenRefreshCoordinator(store: store, refresher: refresher, link: link)

        async let first: AuthTokens = {
            await refresher.callerArrived()
            return try await coordinator.refresh(staleAccessToken: "abc123")
        }()
        async let second: AuthTokens = {
            await refresher.callerArrived()
            return try await coordinator.refresh(staleAccessToken: "abc123")
        }()
        async let third: AuthTokens = {
            await refresher.callerArrived()
            return try await coordinator.refresh(staleAccessToken: "abc123")
        }()

        await refresher.waitForCallers(3)
        for _ in 0..<20 { await Task.yield() }

        #expect(await refresher.callCount == 1)

        await refresher.openGate()

        let results = try await [first, second, third]

        #expect(results == [renewed, renewed, renewed])
        #expect(await refresher.callCount == 1)
    }

    // Would fail if the coordinator refreshed again for a token already renewed by someone else, instead of noticing the store no longer matches what the caller thought was stale.
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

    // Would fail if a failed refresh left the session signed in, or threw something other than `.unauthorized()`.
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

    // Would fail if a cancelled refresh signed the session out, wrongly treating a cancelled request as an invalid token.
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
