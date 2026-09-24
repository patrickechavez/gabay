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
                    Text("Try Again", comment: "Button that retries a failed download")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // `errorDescription` already carries the message; title and icon only switch on failures worth
    // telling apart at a glance, everything else reads as one generic failure.
    private var title: LocalizedStringKey {
        switch error {
        case .offline: "You're offline"
        case .timedOut: "That took too long"
        case .maintenance: "Down for maintenance"
        case .updateRequired: "Update required"
        default: "Something went wrong"
        }
    }

    private var icon: String {
        switch error {
        case .offline: "wifi.exclamationmark"
        case .timedOut: "clock.badge.exclamationmark"
        case .maintenance: "wrench.and.screwdriver"
        case .updateRequired: "arrow.up.circle"
        default: "exclamationmark.triangle"
        }
    }
}
