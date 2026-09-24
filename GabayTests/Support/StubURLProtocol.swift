//
//  StubURLProtocol.swift
//  GabayTests
//

import Foundation
import Testing

// Answers requests from a queue and records what it was asked; shared by every test that stubs a
// network call. The lock makes one read or write atomic, but not a whole
// reset-then-queue-then-request sequence across suites, which Swift Testing still runs in parallel
// even with `@Suite(.serialized)` on each suite alone. So every suite driving a request through
// this stub nests under `SharedStubProtocolSuite` below, whose `.serialized` trait serializes them
// all against each other (see APIClientTests, AuthRepositoryTests, EventRepositoryTests,
// AuthInterceptorTests, LiveTokenRefresherTests).
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    struct Reply {
        var status: Int
        var body: Data
        var headers: [String: String] = [:]
    }

    private static let lock = NSLock()

    nonisolated(unsafe) private static var _replies: [Reply] = []
    nonisolated(unsafe) private static var _asked: [URLRequest] = []

    static var asked: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _asked
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _replies = []
        _asked = []
    }

    static func queue(_ reply: Reply) {
        lock.lock()
        defer { lock.unlock() }
        _replies.append(reply)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._asked.append(request)
        let reply = Self._replies.isEmpty ? nil : Self._replies.removeFirst()
        Self.lock.unlock()

        // Safe to force-unwrap: `request.url` and `reply.status` are always set by the tests that
        // construct them.
        guard let reply else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// Pure namespace: every suite sharing `StubURLProtocol` extends this type, so `.serialized` here
// serializes them all against each other, not just each internally (see the comment above
// `StubURLProtocol`).
@Suite(.serialized)
enum SharedStubProtocolSuite {}
