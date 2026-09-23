//
//  TrailCatalogClientTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

// Serialised: the stub protocol keeps its queue in static storage.
@Suite(.serialized)
struct TrailCatalogClientTests {

    private let base = URL(string: "https://example.test/trails")!

    private func makeClient() -> TrailCatalogClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        StubURLProtocol.reset()
        return TrailCatalogClient(base: base, configuration: configuration)
    }

    private var catalogJSON: Data {
        Data("""
        {
          "version": 1,
          "updated": "2026-09-11",
          "trails": [
            {
              "id": "osmena-peak",
              "name": "Osmeña Peak",
              "region": "Cebu",
              "distanceM": 5200,
              "ascentM": 388,
              "difficulty": "moderate",
              "revision": 1,
              "gpx": "osmena-peak.gpx",
              "bounds": { "north": 9.82, "south": 9.79, "east": 123.41, "west": 123.37 }
            }
          ]
        }
        """.utf8)
    }

    @Test func readsTheCatalogAndItsTag() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: catalogJSON, headers: ["ETag": "\"v1\""]))

        let update = try #require(try await client.catalog(matching: nil))

        #expect(update.catalog.trails.count == 1)
        #expect(update.catalog.trails.first?.name == "Osmeña Peak")
        #expect(update.etag == "\"v1\"")
    }

    @Test func asksForTheCatalogBesideTheBase() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: catalogJSON))

        _ = try await client.catalog(matching: nil)

        #expect(StubURLProtocol.asked.first?.url?.absoluteString
            == "https://example.test/trails/catalog.json")
    }

    // The tag we hold goes out, so the server can answer with nothing.
    @Test func sendsTheTagItWasGiven() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 304, body: Data()))

        _ = try await client.catalog(matching: "\"v1\"")

        let sent = StubURLProtocol.asked.first?.value(forHTTPHeaderField: "If-None-Match")
        #expect(sent == "\"v1\"")
    }

    // Nothing changed, so the copy on disk is still right.
    @Test func returnsNothingWhenTheCatalogIsUnchanged() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 304, body: Data()))

        #expect(try await client.catalog(matching: "\"v1\"") == nil)
    }

    @Test func refusesAnythingOtherThan200Or304() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 404, body: Data()))

        await #expect(throws: TrailCatalogError.badResponse) {
            try await client.catalog(matching: nil)
        }
    }

    @Test func refusesACatalogItCannotDecode() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("not json".utf8)))

        await #expect(throws: (any Error).self) {
            try await client.catalog(matching: nil)
        }
    }

    @Test func fetchesAGPXBesideTheBase() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 200, body: Data("<gpx/>".utf8)))

        let data = try await client.gpx(at: "osmena-peak.gpx")

        #expect(data == Data("<gpx/>".utf8))
        #expect(StubURLProtocol.asked.first?.url?.absoluteString
            == "https://example.test/trails/osmena-peak.gpx")
    }

    // A missing file must not reach the store as an empty trail.
    @Test func refusesAGPXThatIsNotThere() async throws {
        let client = makeClient()
        StubURLProtocol.queue(.init(status: 404, body: Data()))

        await #expect(throws: TrailCatalogError.badResponse) {
            try await client.gpx(at: "gone.gpx")
        }
    }
}
