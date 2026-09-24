//
//  EndpointTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct EndpointTests {

    private let baseWithTrailingSlash = URL(string: "https://api.example.test/")!
    private let baseWithoutTrailingSlash = URL(string: "https://api.example.test")!

    // Pins that trailing/leading slashes are interchangeable with the plain forms; naive
    // concatenation would double or drop a slash on some combinations.
    @Test func joinsPathOntoBaseURLRegardlessOfSurroundingSlashes() throws {
        let expected = "https://api.example.test/events"

        let leadingSlashOnTrailingSlashBase = try Endpoint("/events")
            .urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)
        let leadingSlashOnPlainBase = try Endpoint("/events")
            .urlRequest(baseURL: baseWithoutTrailingSlash, defaultTimeout: 30)
        let plainPathOnTrailingSlashBase = try Endpoint("events")
            .urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)
        let plainPathOnPlainBase = try Endpoint("events")
            .urlRequest(baseURL: baseWithoutTrailingSlash, defaultTimeout: 30)

        #expect(leadingSlashOnTrailingSlashBase.url?.absoluteString == expected)
        #expect(leadingSlashOnPlainBase.url?.absoluteString == expected)
        #expect(plainPathOnTrailingSlashBase.url?.absoluteString == expected)
        #expect(plainPathOnPlainBase.url?.absoluteString == expected)
    }

    // Exercises the split-and-append loop past a single segment; would fail if it dropped a segment
    // or joined them without separators.
    @Test func joinsAMultiSegmentPath() throws {
        let request = try Endpoint("/events/42/rsvp")
            .urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)

        #expect(request.url?.absoluteString == "https://api.example.test/events/42/rsvp")
    }

    // Would fail if query items were ignored, or appended in a way that mangled the URL.
    @Test func composesQueryItemsIntoTheURL() throws {
        let endpoint = Endpoint("events", query: [URLQueryItem(name: "page", value: "2")])
        let request = try endpoint.urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)

        #expect(request.url?.absoluteString == "https://api.example.test/events?page=2")
    }

    // Would fail if query items ran through URLComponents unconditionally, which appends a bare "?"
    // even for an empty array.
    @Test func leavesTheURLUntouchedWhenQueryIsEmpty() throws {
        let request = try Endpoint("events", query: [])
            .urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)

        #expect(request.url?.absoluteString == "https://api.example.test/events")
    }

    // Would fail if the method were not assigned, or the Accept header or a caller-supplied header
    // were dropped.
    @Test func setsMethodAcceptHeaderAndCustomHeaders() throws {
        let endpoint = Endpoint("events", method: .post, headers: ["X-Client": "gabay-ios"])
        let request = try endpoint.urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Client") == "gabay-ios")
    }

    private struct Payload: Encodable {
        var name: String
    }

    // Would fail if a JSON body failed to set httpBody or the Content-Type header, breaking every
    // writing request once the client lands.
    @Test func jsonBodySetsHTTPBodyAndContentType() throws {
        let endpoint = try Endpoint.post("events", body: Payload(name: "trail cleanup"))
        let request = try endpoint.urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)

        #expect(request.httpBody != nil)
        #expect(!(request.httpBody?.isEmpty ?? true))
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    // Inverse of the previous test: would fail if httpBody or Content-Type were set unconditionally
    // instead of inside `if let body`.
    @Test func noBodyLeavesHTTPBodyAndContentTypeUnset() throws {
        let request = try Endpoint("events").urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)

        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    // Would fail if the endpoint's own timeout were ignored in favor of the default.
    @Test func explicitTimeoutOverridesTheDefault() throws {
        let request = try Endpoint("events", timeout: 5)
            .urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)

        #expect(request.timeoutInterval == 5)
    }

    // Would fail if a nil timeout produced some other value (zero, say) instead of falling back to
    // the default.
    @Test func nilTimeoutFallsBackToTheDefault() throws {
        let request = try Endpoint("events", timeout: nil)
            .urlRequest(baseURL: baseWithTrailingSlash, defaultTimeout: 30)

        #expect(request.timeoutInterval == 30)
    }

    // Parameterized over every case so an inverted or shuffled mapping fails on the specific case
    // it gets wrong.
    @Test(arguments: [
        (HTTPMethod.get, true),
        (.put, true),
        (.delete, true),
        (.post, false),
        (.patch, false),
    ])
    func reportsIsIdempotentPerMethod(method: HTTPMethod, expected: Bool) {
        #expect(method.isIdempotent == expected)
    }
}
