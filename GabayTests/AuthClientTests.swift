//
//  AuthClientTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@Suite(.serialized)
struct AuthClientTests {

    private let base = URL(string: "https://example.test/api")!

    // Records the `requiresAuth` flag of every endpoint that passes through
    // it, so a test can pin which calls opt out of the auth interceptor
    // Task 6 will add. An actor rather than a lock-backed class, since new
    // `@unchecked Sendable` types are off the table for this slice.
    private actor RequiresAuthSpy: RequestInterceptor {
        private(set) var values: [Bool] = []

        func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
            values.append(endpoint.requiresAuth)
            return request
        }
    }

    private func makeAPIClient(interceptors: [any RequestInterceptor] = []) -> URLSessionAPIClient {
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

    private func makeClient(interceptors: [any RequestInterceptor] = []) -> AuthClient {
        AuthClient(api: makeAPIClient(interceptors: interceptors))
    }

    @Test func registersAndReturnsATokenAndRole() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"accessToken\":\"abc123\",\"role\":\"hiker\"}".utf8)
        ))

        let result = try await client.register(email: "hiker@example.test", password: "secret123")

        #expect(result == AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        #expect(StubURLProtocol.asked.first?.url?.absoluteString == "https://example.test/api/auth/register")
    }

    @Test func logsInAndReturnsATokenAndRole() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"accessToken\":\"abc123\",\"role\":\"organizer\"}".utf8)
        ))

        let result = try await client.login(email: "organizer@example.test", password: "secret123")

        #expect(result == AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .organizer))
    }

    @Test func readsTheSignedInAccount() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"email\":\"hiker@example.test\",\"role\":\"hiker\"}".utf8)
        ))

        let account = try await client.me()

        #expect(account == Account(email: "hiker@example.test", role: .hiker))
    }

    @Test func refusesBadCredentials() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 401, body: Data()))

        await #expect(throws: APIError.unauthorized()) {
            try await client.login(email: "hiker@example.test", password: "wrong")
        }
    }

    // Would fail if `register` used the protocol extension's default
    // (`requiresAuth: true`), which in Task 6 would make the auth
    // interceptor attach a token to the endpoint that exists to obtain one.
    @Test func registerDoesNotRequireAuth() async throws {
        let spy = RequiresAuthSpy()
        let client = AuthClient(api: makeAPIClient(interceptors: [spy]))
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"accessToken\":\"abc123\",\"role\":\"hiker\"}".utf8)
        ))

        _ = try await client.register(email: "hiker@example.test", password: "secret123")

        #expect(await spy.values == [false])
    }

    // Same failure mode as above, for the other endpoint that must stay
    // token-free: a wrong password returning 401 must not look like an
    // expired session to a future refresh interceptor.
    @Test func loginDoesNotRequireAuth() async throws {
        let spy = RequiresAuthSpy()
        let client = AuthClient(api: makeAPIClient(interceptors: [spy]))
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"accessToken\":\"abc123\",\"role\":\"hiker\"}".utf8)
        ))

        _ = try await client.login(email: "hiker@example.test", password: "secret123")

        #expect(await spy.values == [false])
    }

    // The contrasting case: `me()` is the one auth call that should keep
    // the default. Would fail if it had been flipped to `false` along with
    // the other two.
    @Test func meRequiresAuth() async throws {
        let spy = RequiresAuthSpy()
        let client = AuthClient(api: makeAPIClient(interceptors: [spy]))
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"email\":\"hiker@example.test\",\"role\":\"hiker\"}".utf8)
        ))

        _ = try await client.me()

        #expect(await spy.values == [true])
    }
}
