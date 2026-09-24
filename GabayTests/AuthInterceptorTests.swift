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
}
