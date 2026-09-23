//
//  StubURLProtocol.swift
//  GabayTests
//

import Foundation

// Answers requests from a queue, and keeps what it was asked. Shared by
// every test that stubs a network call instead of talking to a server.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {

    struct Reply {
        var status: Int
        var body: Data
        var headers: [String: String] = [:]
    }

    nonisolated(unsafe) private static var replies: [Reply] = []

    nonisolated(unsafe) private(set) static var asked: [URLRequest] = []

    static func reset() {
        replies = []
        asked = []
    }

    static func queue(_ reply: Reply) {
        replies.append(reply)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.asked.append(request)

        guard !Self.replies.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let reply = Self.replies.removeFirst()
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
