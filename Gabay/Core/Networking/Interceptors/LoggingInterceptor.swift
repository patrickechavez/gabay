//
//  LoggingInterceptor.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import os

struct LoggingInterceptor: RequestInterceptor {

    private let isEnabled: Bool

    init(isEnabled: Bool = APIConfig.isLoggingEnabled) {
        self.isEnabled = isEnabled
    }

    func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
        guard isEnabled else { return request }

        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? "?"
        let headers = LogFormat.headers(request.allHTTPHeaderFields ?? [:])
        let body = request.httpBody.map {
            "\n  body: \(LogFormat.body($0, contentType: endpoint.body?.contentType))"
        } ?? ""

        AppLogger.network.debug(
            """
            → \(method, privacy: .public) \(url, privacy: .public)
              headers:
            \(headers, privacy: .public)\(body, privacy: .public)
            """
        )
        return request
    }

    func didReceive(_ response: HTTPURLResponse, data: Data, for endpoint: Endpoint) async {
        guard isEnabled else { return }

        let status = response.statusCode
        let url = response.url?.absoluteString ?? endpoint.path
        let body = LogFormat.body(data, contentType: response.value(forHTTPHeaderField: "Content-Type"))
        let symbol = (200..<300).contains(status) ? "✓" : "✗"

        let message = """
        ← \(symbol) \(status) \(url)
          body: \(body)
        """

        if (200..<300).contains(status) {
            AppLogger.network.debug("\(message, privacy: .public)")
        } else {
            AppLogger.network.error("\(message, privacy: .public)")
        }
    }
}
