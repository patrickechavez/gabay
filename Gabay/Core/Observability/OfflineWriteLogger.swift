//
//  OfflineWriteLogger.swift
//  Gabay
//  Created by John Patrick Echavez on 9/8/26.
//

import Foundation
import os

// Logs a write saved locally instead of sent; ⇢ means it never left the device.
enum OfflineWriteLogger {

    static func record(_ method: HTTPMethod, path: String? = nil, body: some Encodable) {
        emit(summary(method, path: path), body: LogFormat.body(encoding: body))
    }

    static func record(_ method: HTTPMethod, path: String? = nil, body: Data) {
        emit(summary(method, path: path), body: LogFormat.body(body, contentType: "application/json"))
    }

    // The build is stamped at write time because a queued row can outlive it.
    static func summary(_ method: HTTPMethod, path: String? = nil) -> String {
        let endpoint = path.map { " \($0)" } ?? ""
        let client = "\(ClientMetadata.appVersion)(\(ClientMetadata.appBuild)) iOS \(ClientMetadata.osVersion)"

        return "⇢ \(method.rawValue)\(endpoint)  (offline)  client=\(client)"
    }

    private static func emit(_ summary: String, body: String) {
        guard APIConfig.isLoggingEnabled else { return }

        AppLogger.data.debug("\(summary, privacy: .public)\n  body: \(body, privacy: .public)")
    }
}
