//
//  ErrorStateView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct ErrorStateView: View {

    let error: LoadFailure
    var retry: (@Sendable () async -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
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

    private var title: LocalizedStringKey {
        switch error {
        case .offline: "You're offline"
        case .timedOut: "That took too long"
        case .unavailable: "Not available"
        default: "Something went wrong"
        }
    }

    private var message: LocalizedStringKey {
        switch error {
        case .offline: "Trails already on your phone still work."
        case .timedOut: "The trail did not finish downloading."
        case .unavailable: "That trail is not where the catalogue said it was."
        default: "Try again in a moment."
        }
    }

    private var icon: String {
        switch error {
        case .offline: "wifi.exclamationmark"
        case .timedOut: "clock.badge.exclamationmark"
        case .unavailable: "questionmark.folder"
        default: "exclamationmark.triangle"
        }
    }
}
