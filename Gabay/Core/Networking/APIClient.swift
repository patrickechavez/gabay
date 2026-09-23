//
//  APIClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

// Talks to the events/auth backend. AuthClient and EventClient both build
// on this rather than each rolling their own URLSession and status-code
// handling.
struct APIClient: Sendable {

    // A request that has not answered in this long is not worth waiting for.
    private static let timeout: TimeInterval = 20

    let base: URL

    private let session: URLSession
    private let tokenProvider: @Sendable () -> String?

    // The configuration is a parameter so a test can hand it a stub
    // protocol. The token provider reads the current session token on every
    // call, so one client instance works before and after sign-in.
    init(
        base: URL,
        configuration: URLSessionConfiguration = .default,
        tokenProvider: @escaping @Sendable () -> String? = { nil }
    ) {
        self.base = base
        self.tokenProvider = tokenProvider

        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    func get<Response: Decodable>(_ path: String) async throws -> Response {
        try await send(makeRequest(path: path, method: "GET"))
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        var request = makeRequest(path: path, method: "POST")
        request.httpBody = try JSONEncoder.api.encode(body)
        return try await send(request)
    }

    // For calls whose success carries nothing worth decoding, like joining an event.
    func post(_ path: String) async throws {
        _ = try await sendRaw(makeRequest(path: path, method: "POST"))
    }

    private func makeRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: base.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        try JSONDecoder.api.decode(Response.self, from: try await sendRaw(request))
    }

    private func sendRaw(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }

        switch http.statusCode {
        case 200..<300: return data
        case 401: throw APIError.unauthorized
        case 403: throw APIError.forbidden
        case 400, 422: throw APIError.validationFailed
        default: throw APIError.server
        }
    }
}

enum APIError: Error, Equatable {
    case badResponse
    case unauthorized
    case forbidden
    case validationFailed
    case server
}
