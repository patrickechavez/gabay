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

    private func makeClient() -> AuthClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return AuthClient(api: APIClient(base: base, configuration: configuration))
    }

    @Test func registersAndReturnsATokenAndRole() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"token\":\"abc123\",\"role\":\"hiker\"}".utf8)
        ))

        let result = try await client.register(email: "hiker@example.test", password: "secret123")

        #expect(result == AuthResult(token: "abc123", role: .hiker))
        #expect(StubURLProtocol.asked.first?.url?.absoluteString == "https://example.test/api/auth/register")
    }

    @Test func logsInAndReturnsATokenAndRole() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(
            status: 200,
            body: Data("{\"token\":\"abc123\",\"role\":\"organizer\"}".utf8)
        ))

        let result = try await client.login(email: "organizer@example.test", password: "secret123")

        #expect(result == AuthResult(token: "abc123", role: .organizer))
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
}
