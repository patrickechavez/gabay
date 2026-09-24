//
//  LogFormat.swift
//  Gabay
//

import Foundation

// Shared by the network and offline logs so both print identically.
enum LogFormat {

    // Authorization carries a bearer token, the same kind of secret
    // `redactedBodyKeys` below already redacts when it shows up in a
    // request body (as "token", "access_token", "refresh_token"). Gabay
    // also stores a refresh token, which lives longer and does more damage
    // if it leaks than an access token does. Redacting it here costs
    // nothing for debugging - you can still see that the header was
    // attached, just not its value - and the auth interceptor tests
    // already assert attachment without needing it in the console.
    //
    // Divergence from the template: upstream logs Authorization in full.
    private static let redactedHeaders: Set<String> = [
        "cookie", "set-cookie", "x-api-key", "proxy-authorization", "authorization"
    ]

    // Divergence from the template: entries below are spelled snake_case
    // for readability, but Gabay's coders (see APICoders.swift) do not
    // convert between snake_case and camelCase, so a key can arrive on
    // the wire in either spelling depending on the endpoint - AuthResult's
    // "accessToken" and "refreshToken" are camelCase, for example. Matching
    // must therefore be spelling-agnostic rather than assuming one
    // convention, which is what `normalizedRedactedBodyKeys` and
    // `normalize(_:)` below are for.
    private static let redactedBodyKeys: Set<String> = [
        "password", "current_password", "new_password", "password_confirmation",
        "token", "access_token", "refresh_token", "secret", "otp", "pin", "code"
    ]

    // Precomputed once so redaction doesn't re-normalize every entry in
    // `redactedBodyKeys` for every key of every logged body.
    private static let normalizedRedactedBodyKeys: Set<String> = Set(redactedBodyKeys.map(normalize))

    // Lowercases and strips underscores so "access_token", "accessToken",
    // "AccessToken" and "ACCESS_TOKEN" all normalize to the same string.
    private static func normalize(_ key: String) -> String {
        key.lowercased().replacingOccurrences(of: "_", with: "")
    }

    private static let maxBodyBytes = 4_000

    static func headers(_ headers: [String: String]) -> String {
        guard !headers.isEmpty else { return "none" }

        return headers
            .sorted { $0.key < $1.key }
            .map { key, value in
                redactedHeaders.contains(key.lowercased())
                    ? "    \(key): <redacted>"
                    : "    \(key): \(value)"
            }
            .joined(separator: "\n")
    }

    static func body(_ body: Data, contentType: String? = nil) -> String {
        guard !body.isEmpty else { return "<empty>" }

        if let contentType, contentType.contains("multipart/form-data") {
            return "<multipart, \(body.count) bytes>"
        }

        guard body.count <= maxBodyBytes else {
            return "<\(body.count) bytes - too large to log>"
        }

        if let object = try? JSONSerialization.jsonObject(with: body) {
            let redacted = redact(object)
            if let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
        }

        guard let text = String(data: body, encoding: .utf8) else {
            return "<\(body.count) bytes, not UTF-8>"
        }
        return text
    }

    // Encodes the model the way the API client would.
    static func body(encoding value: some Encodable) -> String {
        guard let data = try? JSONEncoder.api.encode(value) else { return "<not encodable>" }

        return body(data, contentType: "application/json")
    }

    private static func redact(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                result[entry.key] = normalizedRedactedBodyKeys.contains(normalize(entry.key))
                    ? "<redacted>"
                    : redact(entry.value)
            }
        }
        if let array = value as? [Any] {
            return array.map(redact)
        }
        return value
    }
}
