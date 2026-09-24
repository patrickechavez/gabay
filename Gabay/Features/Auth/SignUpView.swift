//
//  SignUpView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

@Observable
@MainActor
final class SignUpViewModel {

    let action = ActionState()

    // Backed by its own storage with a hand-written setter, rather than a
    // plain stored property, so every edit clears a stale failure through
    // the one shared `ActionState.clear()` instead of leaving it on screen
    // until a resubmit that a bad edit may never allow.
    private var storedEmail = ""
    private var storedPassword = ""

    var email: String {
        get { storedEmail }
        set { storedEmail = newValue; action.clear() }
    }

    var password: String {
        get { storedPassword }
        set { storedPassword = newValue; action.clear() }
    }

    @ObservationIgnored private let session: Session

    // A backend-defined minimum; the form just avoids an obviously-too-short
    // password making a wasted round trip.
    private static let minimumPasswordLength = 8

    init(session: Session) {
        self.session = session
    }

    // An empty field is never an inline error. It shows as the required
    // marker and a disabled button, so only a filled-in field can be wrong.
    // A server-supplied message, when there is one, wins over the local rule.
    var emailError: String? {
        if let serverMessage = action.message(for: "email") { return serverMessage }
        guard !email.trimmed.isEmpty, !email.trimmed.isValidEmail else { return nil }
        return String(
            localized: "Enter a valid email address.",
            comment: "Validation message shown for a malformed email address"
        )
    }

    var passwordError: String? {
        if let serverMessage = action.message(for: "password") { return serverMessage }
        guard !password.isEmpty, password.count < Self.minimumPasswordLength else { return nil }
        return String(
            localized: "Use at least \(Self.minimumPasswordLength) characters.",
            comment: "Validation message shown when a password is too short"
        )
    }

    // A field-level message is already shown next to its own field, so the
    // whole-form line only carries what's left over.
    var signUpErrorMessage: String? {
        guard action.error?.validationErrors == nil else { return nil }
        return action.errorMessage
    }

    var canSubmit: Bool {
        email.trimmed.isValidEmail
            && password.count >= Self.minimumPasswordLength
            && !action.isRunning
    }

    func register() async -> Bool {
        guard canSubmit else { return false }

        let credentials = (email: email.trimmed, password: password)
        let succeeded: Void? = await action.run { [session] in
            try await session.register(email: credentials.email, password: credentials.password)
        }
        return succeeded != nil
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
                        isRunning: viewModel.action.isRunning,
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
