//
//  StubURLProtocol.swift
//  GabayTests
//

import Foundation

// Answers requests from a queue, and keeps what it was asked. Shared by
// every test that stubs a network call instead of talking to a server.
//
// The lock makes each read or write atomic, but does not make a whole
// reset-then-queue-then-request sequence atomic across suites: two
// different test suites running concurrently could still interleave their
// sequences and steal each other's queued reply. Suites sharing this stub
// should stay `@Suite(.serialized)` internally; true cross-suite isolation
// would need per-client reply routing, not attempted here.
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

        // Safe to force-unwrap: `request.url` and `reply.status` are always
        // set by the tests that construct them, never derived from external input.
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
