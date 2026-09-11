//
//  LogFormat.swift
//  Gabay
//  Created by John Patrick Echavez on 9/8/26.
//

import Foundation

// Shared by the network and offline logs so both print identically.
enum LogFormat {

    // Authorization is logged in full; logging is on in Development only.
    private static let redactedHeaders: Set<String> = [
        "cookie", "set-cookie", "x-api-key", "proxy-authorization"
    ]

    private static let redactedBodyKeys: Set<String> = [
        "password", "current_password", "new_password", "password_confirmation",
        "token", "access_token", "refresh_token", "secret", "otp", "pin", "code"
    ]

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
            return "<\(body.count) bytes — too large to log>"
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
                result[entry.key] = redactedBodyKeys.contains(entry.key.lowercased())
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
