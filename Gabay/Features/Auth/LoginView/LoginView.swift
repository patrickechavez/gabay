//
//  LoginView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct LoginView: View {

    @State private var viewModel: LoginViewModel
    @Environment(Router<AuthRoute>.self) private var router

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    init(viewModel: LoginViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                EmailField(
                    text: $viewModel.email,
                    error: viewModel.emailError,
                    isRequired: true
                )
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

                PasswordField(
                    text: $viewModel.password,
                    error: viewModel.passwordError
                )
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }

                if let error = viewModel.generalError {
                    InlineErrorText(error)
                }

                AsyncButton(
                    title: Text("Sign In", comment: "Primary button on the sign-in screen"),
                    isRunning: viewModel.action.isRunning,
                    action: { await viewModel.signIn() }
                )
                .disabled(!viewModel.canSubmit)

                HStack {
                    Button {
                        router.push(.register)
                    } label: {
                        Text("Create an account", comment: "Link to the registration screen")
                    }

                    Spacer()

                    Button {
                        router.push(.forgotPassword)
                    } label: {
                        Text("Forgot password?", comment: "Link to the password reset screen")
                    }
                }
                .font(Theme.Font.secondary)
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Text("Welcome", comment: "Title of the sign-in screen"))
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.signIn() }
    }
}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            LoginView(viewModel: dependencies.makeLoginViewModel())
        }
        .environment(Router<AuthRoute>())
    }
}

#endif
