//
//  AuthInterceptorTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

// `adapt(_:for:)` never needs to refresh in these tests: every stored token
// here has no expiry, so `needsProactiveRefresh` is always false. A
// refresher that throws makes that assumption load-bearing instead of
// incidental.
private struct UnreachableRefresher: TokenRefreshing {
    func refresh(using refreshToken: String) async throws -> AuthTokens {
        throw APIError.server(status: 500)
    }
}

// Returns a fixed set of renewed tokens, for tests that drive a real
// `handle(_:for:attempt:)` retry and need the refresh to actually succeed.
private struct StubTokenRefresher: TokenRefreshing {
    let renewed: AuthTokens

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        renewed
    }
}

// Always throws a configured error, for tests that need
// `coordinator.refresh` to fail in a specific way rather than succeed.
private struct FailingTokenRefresher: TokenRefreshing {
    let error: APIError

    func refresh(using refreshToken: String) async throws -> AuthTokens {
        throw error
    }
}

extension SharedStubProtocolSuite {

// `.serialized`: some tests below drive a real `URLSessionAPIClient` against
// `StubURLProtocol`, whose queue is shared static state (see its own
// comment); running this suite's tests concurrently against each other
// could let one test's request steal another's queued reply.
@Suite(.serialized)
@MainActor
struct AuthInterceptorTests {

    private let base = URL(string: "https://example.test/api")!

    private func makeInterceptor(tokens: AuthTokens?) -> AuthInterceptor {
        let store = InMemoryTokenStore(tokens: tokens)
        let coordinator = TokenRefreshCoordinator(
            store: store,
            refresher: UnreachableRefresher(),
            link: SessionLink()
        )
        return AuthInterceptor(coordinator: coordinator)
    }

    private func makeSignedInSession() async throws -> Session {
        let auth = StubAuthenticating()
        auth.loginResult = .success(
            AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker)
        )
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        let session = Session(auth: auth, tokenStore: InMemoryTokenStore())
        try await session.login(email: "hiker@example.test", password: "secret123")
        return session
    }

    private func makeAPIClient(interceptors: [any RequestInterceptor]) -> URLSessionAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return URLSessionAPIClient(
            baseURL: base,
            session: URLSession(configuration: configuration),
            interceptors: interceptors,
            retryPolicy: .none
        )
    }

    // Would fail if the header were missing, misspelled, or the token
    // weren't the one in the store; restores the coverage Task 4 dropped
    // when `tokenProvider` was removed with no interceptor yet to test.
    @Test func attachesTheTokenWhenAuthIsRequiredAndATokenExists() async throws {
        let interceptor = makeInterceptor(tokens: AuthTokens(accessToken: "abc123"))
        let endpoint = Endpoint.get("thing", requiresAuth: true)
        let request = try endpoint.urlRequest(baseURL: base, defaultTimeout: 30)

        let adapted = try await interceptor.adapt(request, for: endpoint)

        #expect(adapted.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")
    }

    // Would fail if a token were attached to a request that declared it
    // doesn't need one, leaking a credential the endpoint never asked for.
    @Test func leavesTheHeaderOffWhenAuthIsNotRequired() async throws {
        let interceptor = makeInterceptor(tokens: AuthTokens(accessToken: "abc123"))
        let endpoint = Endpoint.get("thing", requiresAuth: false)
        let request = try endpoint.urlRequest(baseURL: base, defaultTimeout: 30)

        let adapted = try await interceptor.adapt(request, for: endpoint)

        #expect(adapted.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // Would fail if the interceptor attached a header built from an absent
    // or empty token, e.g. `"Bearer "` or `"Bearer nil"`.
    @Test func leavesTheHeaderOffWhenNoTokenIsStored() async throws {
        let interceptor = makeInterceptor(tokens: nil)
        let endpoint = Endpoint.get("thing", requiresAuth: true)
        let request = try endpoint.urlRequest(baseURL: base, defaultTimeout: 30)

        let adapted = try await interceptor.adapt(request, for: endpoint)

        #expect(adapted.value(forHTTPHeaderField: "Authorization") == nil)
    }

    // Would fail if `handle(_:for:attempt:)` retried without the refresh
    // actually having happened first, or if `attemptOnce` didn't re-run
    // `adapt` on the retried request: either way the second request would
    // still carry the stale token instead of the renewed one.
    @Test func retriedRequestCarriesTheRefreshedTokenNotTheStaleOne() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "stale-token", refreshToken: "refresh1"))
        let renewed = AuthTokens(accessToken: "renewed-token", refreshToken: "refresh2")
        let coordinator = TokenRefreshCoordinator(
            store: store,
            refresher: StubTokenRefresher(renewed: renewed),
            link: SessionLink()
        )
        let interceptor = AuthInterceptor(coordinator: coordinator)
        let client = makeAPIClient(interceptors: [interceptor])
        StubURLProtocol.queue(.init(status: 401, body: Data()))
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":1}".utf8)))

        struct Payload: Decodable, Equatable { let value: Int }
        let payload: Payload = try await client.get("thing")

        #expect(payload == Payload(value: 1))
        #expect(StubURLProtocol.asked.count == 2)
        #expect(StubURLProtocol.asked[0].value(forHTTPHeaderField: "Authorization") == "Bearer stale-token")
        #expect(StubURLProtocol.asked[1].value(forHTTPHeaderField: "Authorization") == "Bearer renewed-token")
    }

    // Would fail if a 401 with no refresh token available kept retrying
    // forever instead of failing, or if the session were left signed in
    // after a token that cannot be refreshed was rejected.
    @Test func aTokenThatCannotBeRefreshedEndsTheSessionAndSurfacesTheError() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "abc123", refreshToken: nil))
        let session = try await makeSignedInSession()
        let link = SessionLink()
        link.session = session
        let coordinator = TokenRefreshCoordinator(store: store, refresher: UnreachableRefresher(), link: link)
        let interceptor = AuthInterceptor(coordinator: coordinator)
        let client = makeAPIClient(interceptors: [interceptor])
        StubURLProtocol.queue(.init(status: 401, body: Data()))

        struct Payload: Decodable, Equatable { let value: Int }
        await #expect(throws: APIError.unauthorized()) {
            let _: Payload = try await client.get("thing")
        }

        #expect(StubURLProtocol.asked.count == 1)
        #expect(session.isSignedIn == false)
    }

    // Would fail if `handle(_:for:attempt:)` let a cancelled refresh fall
    // through to the branch above it: that would surface `.unauthorized`
    // instead of `.cancelled` (misreporting a plain request cancellation as
    // an expired session), and would call `coordinator.invalidate()`,
    // wrongly signing the user out and clearing their tokens over a
    // cancellation that says nothing about whether the token is still good.
    @Test func cancelledRefreshFailsWithCancelledAndLeavesTheSessionIntact() async throws {
        let store = InMemoryTokenStore(tokens: AuthTokens(accessToken: "abc123", refreshToken: "refresh1"))
        let session = try await makeSignedInSession()
        let link = SessionLink()
        link.session = session
        let coordinator = TokenRefreshCoordinator(
            store: store,
            refresher: FailingTokenRefresher(error: .cancelled),
            link: link
        )
        let interceptor = AuthInterceptor(coordinator: coordinator)
        let endpoint = Endpoint.get("thing", requiresAuth: true)

        let decision = await interceptor.handle(.unauthorized(), for: endpoint, attempt: 1)

        #expect(decision == .fail(.cancelled))
        #expect(session.isSignedIn == true)
        #expect(await store.load() != nil)
    }
}
}
