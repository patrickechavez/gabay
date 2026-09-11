//
//  APIConfig.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

enum APIConfig {

    static let baseURL: URL = {
        guard let value = string("API_BASE_URL"), let url = URL(string: value) else {
            preconditionFailure(
                """
                API_BASE_URL is missing or invalid in Info.plist.
                Set it in Config/<Environment>.xcconfig — remember to escape the \
                double slash as `https:/$()/example.com`.
                """
            )
        }
        return url
    }()

    static let timeout: TimeInterval = double("API_TIMEOUT_SECONDS") ?? 30

    static let maxAttempts: Int = int("API_MAX_RETRIES").map { $0 + 1 } ?? 3

    static let isLoggingEnabled: Bool = bool("API_LOGGING_ENABLED")

    /// Unused — the live gate is a 426 from the server, not this flag.
    static let isForceUpdateEnabled: Bool = bool("FORCE_UPDATE_ENABLED")

    static let isCertificatePinningEnabled: Bool = bool("CERT_PINNING_ENABLED")

    /// SPKI hashes for pinning; blank is a safe no-op that falls back to TLS trust.
    static let pinnedPublicKeyHashes: [String] = {
        guard isCertificatePinningEnabled else { return [] }
        return (string("PINNED_PUBLIC_KEY_HASHES") ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }()

    static let updateURL: URL? = string("UPDATE_URL").flatMap(URL.init(string:))

    static var retryPolicy: RetryPolicy {
        maxAttempts <= 1 ? .none : RetryPolicy(maxAttempts: maxAttempts)
    }

    static let urlScheme: String = string("APP_URL_SCHEME") ?? "gabay"

    /// Only ever hides the ribbon — Production compiles it out regardless.
    static let isEnvironmentBannerEnabled: Bool = bool("ENV_BANNER_ENABLED")

    private static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func int(_ key: String) -> Int? { string(key).flatMap(Int.init) }

    private static func double(_ key: String) -> Double? { string(key).flatMap(Double.init) }

    private static func bool(_ key: String) -> Bool {
        switch string(key)?.uppercased() {
        case "YES", "TRUE", "1": true
        default: false
        }
    }
}
