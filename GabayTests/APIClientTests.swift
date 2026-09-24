//
//  APIClientTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

extension SharedStubProtocolSuite {

@Suite(.serialized)
struct APIClientTests {

    private let base = URL(string: "https://example.test/api")!

    private func makeClient() -> URLSessionAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return URLSessionAPIClient(
            baseURL: base,
            session: URLSession(configuration: configuration),
            retryPolicy: .none
        )
    }

    private struct Payload: Codable, Equatable, Sendable {
        let value: Int
    }

    // Would fail if the GET path never reached the decoder, or decoded the wrong type.
    @Test func decodesAGetResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":1}".utf8)))

        let payload: Payload = try await client.get("thing")

        #expect(payload == Payload(value: 1))
    }

    // Would fail if the POST body were dropped, or the method sent were not POST.
    @Test func sendsAPostBodyAndDecodesTheResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":2}".utf8)))

        let payload: Payload = try await client.post("thing", body: Payload(value: 2))

        #expect(payload == Payload(value: 2))
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    // Would fail if a bodiless send() threw on a response it has no type to decode into, instead of silently succeeding.
    @Test func bodilessPostIgnoresTheResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 204, body: Data()))

        try await client.send(Endpoint("thing/join", method: .post))

        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    // Fails if a 401 maps to any other case, or isn't mapped (then `#expect(throws:)` fails differently).
    @Test func mapsA401ToUnauthorized() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 401, body: Data()))

        await #expect(throws: APIError.unauthorized()) {
            let _: Payload = try await client.get("thing")
        }
    }

    // Would fail if a 403 were mapped to any other case.
    @Test func mapsA403ToForbidden() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 403, body: Data()))

        await #expect(throws: APIError.forbidden()) {
            let _: Payload = try await client.get("thing")
        }
    }

    // Would fail if a 422 were mapped to any other case; named for the `.validation` case the mapping produces.
    @Test func mapsA422ToValidation() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 422, body: Data()))

        await #expect(throws: APIError.validation(ValidationErrors(fields: [:], summary: nil))) {
            let _: Payload = try await client.get("thing")
        }
    }

    // Would fail if an unrecognized status stopped falling through to the generic `.server` case.
    @Test func mapsAnythingElseToServer() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 500, body: Data()))

        await #expect(throws: APIError.server(status: 500)) {
            let _: Payload = try await client.get("thing")
        }
    }

    // Fails if the empty-body shortcut is removed; JSONDecoder can't decode zero bytes, so this would throw `decodingFailed` instead of yielding `EmptyResponse`.
    @Test func decodesAnEmptyBodyOn2xxAsEmptyResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data()))

        let response: EmptyResponse = try await client.get("thing")

        #expect(response == EmptyResponse())
    }
}
}
