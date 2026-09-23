//
//  SignUpView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

@Observable
@MainActor
final class SignUpViewModel {

    var email = ""
    var password = ""

    private(set) var isRegistering = false
    private(set) var failure: LoadFailure?

    @ObservationIgnored private let session: Session

    // A backend-defined minimum; the form just avoids an obviously-too-short
    // password making a wasted round trip.
    private static let minimumPasswordLength = 8

    init(session: Session) {
        self.session = session
    }

    // An empty field is never an inline error. It shows as the required
    // marker and a disabled button, so only a filled-in field can be wrong.
    var emailError: String? {
        guard !email.trimmed.isEmpty, !email.trimmed.isValidEmail else { return nil }
        return String(
            localized: "Enter a valid email address.",
            comment: "Validation message shown for a malformed email address"
        )
    }

    var passwordError: String? {
        guard !password.isEmpty, password.count < Self.minimumPasswordLength else { return nil }
        return String(
            localized: "Use at least \(Self.minimumPasswordLength) characters.",
            comment: "Validation message shown when a password is too short"
        )
    }

    var signUpErrorMessage: String? {
        guard let failure, failure.isUserFacing else { return nil }
        return String(localized: "Try again in a moment.", comment: "Shown when sign-up fails")
    }

    var canSubmit: Bool {
        email.trimmed.isValidEmail
            && password.count >= Self.minimumPasswordLength
            && !isRegistering
    }

    func register() async -> Bool {
        guard canSubmit else { return false }

        failure = nil
        isRegistering = true
        defer { isRegistering = false }

        do {
            try await session.register(email: email.trimmed, password: password)
            return true
        } catch {
            failure = LoadFailure.classify(error)
            return false
        }
    }
}

struct SignUpView: View {

    @State private var viewModel: SignUpViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SignUpViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    EmailField(
                        text: $viewModel.email,
                        error: viewModel.emailError,
                        isRequired: true
                    )

                    PasswordField(
                        text: $viewModel.password,
                        error: viewModel.passwordError,
                        isRequired: true,
                        isNewPassword: true
                    )

                    if let message = viewModel.signUpErrorMessage {
                        InlineErrorText(message)
                    }

                    AsyncButton(
                        title: Text("Create Account", comment: "Button that submits the sign-up form"),
                        isRunning: viewModel.isRegistering,
                        action: {
                            if await viewModel.register() {
                                await MainActor.run { dismiss() }
                            }
                        }
                    )
                    .disabled(!viewModel.canSubmit)
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Sign Up", comment: "Title of the account creation screen"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel", comment: "Closes the sign-up screen without creating an account")
                    }
                }
            }
        }
    }
}
