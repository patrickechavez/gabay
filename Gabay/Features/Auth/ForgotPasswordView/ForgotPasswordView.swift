//
//  ForgotPasswordView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct ForgotPasswordView: View {

    @State private var viewModel: ForgotPasswordViewModel

    init(viewModel: ForgotPasswordViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if viewModel.didSend {
                    ContentUnavailableView {
                        Label {
                            Text("Check your email", comment: "Title shown after a password reset is requested")
                        } icon: {
                            Image(systemName: "envelope.badge")
                        }
                    } description: {
                        Text(viewModel.confirmation)
                    }
                } else {
                    Text(
                        "Enter the email address for your account and we'll send you a link to reset your password.",
                        comment: "Explanatory text on the forgot-password screen"
                    )
                    .font(Theme.Font.secondary)
                    .foregroundStyle(Theme.Color.secondaryText)

                    EmailField(text: $viewModel.email, error: viewModel.emailError, isRequired: true)

                    if let error = viewModel.generalError {
                        InlineErrorText(error)
                    }

                    AsyncButton(
                        title: Text("Send Reset Link", comment: "Button that requests a password reset email"),
                        isRunning: viewModel.action.isRunning,
                        action: { await viewModel.submit() }
                    )
                    .disabled(!viewModel.canSubmit)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(Theme.Animation.standard, value: viewModel.didSend)
        .navigationTitle(Text("Reset Password", comment: "Title of the forgot-password screen"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResetPasswordView: View {

    @State private var viewModel: ResetPasswordViewModel

    init(viewModel: ResetPasswordViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if viewModel.didReset {
                    ContentUnavailableView {
                        Label {
                            Text("Password changed", comment: "Title shown after a password has been reset")
                        } icon: {
                            Image(systemName: "checkmark.circle")
                        }
                    } description: {
                        Text(viewModel.confirmationMessage)
                    }
                } else {
                    Text("Choose a new password for your account.",
                         comment: "Explanatory text on the reset-password screen")
                        .font(Theme.Font.secondary)
                        .foregroundStyle(Theme.Color.secondaryText)

                    PasswordField(
                        text: $viewModel.password,
                        label: String(localized: "New password", comment: "Label for the new password field"),
                        error: viewModel.passwordError,
                        isRequired: true,
                        isNewPassword: true
                    )

                    PasswordField(
                        text: $viewModel.confirmation,
                        label: String(
                            localized: "Confirm password",
                            comment: "Label for the password confirmation field"
                        ),
                        error: viewModel.confirmationError,
                        isRequired: true,
                        isNewPassword: true
                    )

                    if let error = viewModel.generalError {
                        InlineErrorText(error)
                    }

                    AsyncButton(
                        title: Text("Set New Password", comment: "Button that submits a new password"),
                        isRunning: viewModel.action.isRunning,
                        action: { await viewModel.submit() }
                    )
                    .disabled(!viewModel.canSubmit)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .animation(Theme.Animation.standard, value: viewModel.didReset)
        .navigationTitle(Text("Choose a Password", comment: "Title of the reset-password screen"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            ForgotPasswordView(viewModel: dependencies.makeForgotPasswordViewModel())
        }
    }
}

#endif
