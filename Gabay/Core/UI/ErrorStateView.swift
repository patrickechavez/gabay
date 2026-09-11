//
//  ErrorStateView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct ErrorStateView: View {

    let error: APIError
    var retry: (@Sendable () async -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(error.localizedDescription)
        } actions: {
            if let retry, error.isRetryable {
                Button {
                    Task { await retry() }
                } label: {
                    Text("Try Again", comment: "Button that retries a failed network request")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var title: LocalizedStringKey {
        switch error {
        case .offline: "You're offline"
        case .timedOut: "That took too long"
        case .notFound: "Not found"
        case .forbidden: "No access"
        case .maintenance: "Temporarily unavailable"
        case .updateRequired: "Update required"
        default: "Something went wrong"
        }
    }

    private var icon: String {
        switch error {
        case .offline, .transport: "wifi.exclamationmark"
        case .timedOut: "clock.badge.exclamationmark"
        case .notFound: "questionmark.folder"
        case .forbidden, .unauthorized: "lock"
        case .maintenance: "wrench.and.screwdriver"
        case .updateRequired: "arrow.down.circle"
        default: "exclamationmark.triangle"
        }
    }
}
