//
//  LogFormat.swift
//  Gabay
//

import Foundation

// Shared by the network and offline logs so both print identically.
enum LogFormat {

    // Authorization carries a bearer token, and Gabay's refresh token does more damage than an
    // access token if it leaks. Redacting it here is free for debugging (attachment is still
    // visible, just not the value) and the auth interceptor tests don't need it in the console.
    // Diverges from the template, which logs Authorization in full.
    private static let redactedHeaders: Set<String> = [
        "cookie", "set-cookie", "x-api-key", "proxy-authorization", "authorization"
    ]

    // Spelled snake_case for readability, but Gabay's coders (APICoders.swift) don't convert
    // case, so a key can arrive on the wire in either spelling. `normalizedRedactedBodyKeys`
    // and `normalize(_:)` below make matching spelling-agnostic instead of assuming one.
    private static let redactedBodyKeys: Set<String> = [
        "password", "current_password", "new_password", "password_confirmation",
        "token", "access_token", "refresh_token", "secret", "otp", "pin", "code"
    ]

    // Precomputed once so redaction doesn't re-normalize `redactedBodyKeys` on every logged body.
    private static let normalizedRedactedBodyKeys: Set<String> = Set(redactedBodyKeys.map(normalize))

    // Lowercases and strips underscores so "access_token", "accessToken", "AccessToken" and "ACCESS_TOKEN" all normalize the same.
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
