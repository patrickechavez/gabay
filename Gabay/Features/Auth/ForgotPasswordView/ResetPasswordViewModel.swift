//
//  ResetPasswordViewModel.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class ResetPasswordViewModel {

    var password = ""
    var confirmation = ""
    let action = ActionState()

    private(set) var didReset = false

    @ObservationIgnored private let token: String
    @ObservationIgnored private let auth: any AuthRepository

    init(token: String, auth: any AuthRepository) {
        self.token = token
        self.auth = auth
    }

    var canSubmit: Bool {
        !password.isEmpty && password == confirmation && !action.isRunning
    }

    var passwordError: String? {
        action.message(for: "password")
    }

    // Only complains once the user has typed something to compare against.
    var confirmationError: String? {
        guard !confirmation.isEmpty, password != confirmation else { return nil }
        return String(
            localized: "Passwords don't match.",
            comment: "Validation message when passwords differ"
        )
    }

    var generalError: String? {
        guard action.error?.validationErrors == nil else { return nil }
        return action.errorMessage
    }

    var confirmationMessage: String {
        String(
            localized: "Your password has been changed. You can now sign in with it.",
            comment: "Confirmation shown after a password has been reset"
        )
    }

    func submit() async {
        guard canSubmit else { return }

        let newPassword = password
        let result: Void? = await action.run { [auth, token] in
            try await auth.resetPassword(token: token, newPassword: newPassword)
        }
        guard result != nil else { return }

        // Clear the fields so the new password isn't left sitting in memory.
        password = ""
        confirmation = ""
        didReset = true
    }
}
