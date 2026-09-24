//
//  APIClientTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@Suite(.serialized)
struct APIClientTests {

    private let base = URL(string: "https://example.test/api")!

    private func makeClient(token: String? = nil) -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return APIClient(base: base, configuration: configuration, tokenProvider: { token })
    }

    private struct Payload: Codable, Equatable {
        let value: Int
    }

    @Test func decodesAGetResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":1}".utf8)))

        let payload: Payload = try await client.get("thing")

        #expect(payload == Payload(value: 1))
    }

    @Test func sendsAPostBodyAndDecodesTheResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":2}".utf8)))

        let payload: Payload = try await client.post("thing", body: Payload(value: 2))

        #expect(payload == Payload(value: 2))
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    @Test func postWithoutABodyIgnoresTheResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 204, body: Data()))

        try await client.post("thing/join")

        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
    }

    @Test func attachesTheTokenWhenThereIsOne() async throws {
        let client = makeClient(token: "abc123")
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":1}".utf8)))

        let _: Payload = try await client.get("thing")

        #expect(StubURLProtocol.asked.first?.value(forHTTPHeaderField: "Authorization") == "Bearer abc123")
    }

    @Test func sendsNoAuthorizationHeaderWithoutAToken() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":1}".utf8)))

        let _: Payload = try await client.get("thing")

        #expect(StubURLProtocol.asked.first?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func mapsA401ToUnauthorized() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 401, body: Data()))

        await #expect(throws: APIError.unauthorized()) {
            let _: Payload = try await client.get("thing")
        }
    }

    @Test func mapsA403ToForbidden() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 403, body: Data()))

        await #expect(throws: APIError.forbidden()) {
            let _: Payload = try await client.get("thing")
        }
    }

    @Test func mapsA422ToValidationFailed() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 422, body: Data()))

        await #expect(throws: APIError.validation(ValidationErrors(fields: [:], summary: nil))) {
            let _: Payload = try await client.get("thing")
        }
    }

    @Test func mapsAnythingElseToServer() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 500, body: Data()))

        await #expect(throws: APIError.server(status: 500)) {
            let _: Payload = try await client.get("thing")
        }
    }

    @Test func sendsAMultipartUploadAndDecodesTheResponse() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("{\"value\":3}".utf8)))

        let fileURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).gpx")
        try Data("<gpx></gpx>".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let payload: Payload = try await client.postMultipart(
            "thing",
            fileURL: fileURL,
            fieldName: "gpx",
            filename: "route.gpx",
            mimeType: "application/gpx+xml",
            fields: ["distanceM": "500"]
        )

        #expect(payload == Payload(value: 3))
        #expect(StubURLProtocol.asked.first?.httpMethod == "POST")
        #expect(StubURLProtocol.asked.first?.value(forHTTPHeaderField: "Content-Type")?
            .hasPrefix("multipart/form-data; boundary=") == true)
    }
}
