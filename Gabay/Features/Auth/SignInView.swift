//
//  SignInView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

@Observable
@MainActor
final class SignInViewModel {

    var email = ""
    var password = ""

    private(set) var isSigningIn = false
    private(set) var failure: LoadFailure?

    @ObservationIgnored private let session: Session

    init(session: Session) {
        self.session = session
    }

    // Sign-in deliberately has no inline field validation. A local rule here
    // would gate canSubmit, and a false negative would lock someone out of
    // their own account over an unusual but legal address. The server decides.
    var canSubmit: Bool {
        !email.trimmed.isEmpty && !password.isEmpty && !isSigningIn
    }

    var signInErrorMessage: String? {
        guard let failure, failure.isUserFacing else { return nil }
        return String(
            localized: "Check your email and password, then try again.",
            comment: "Shown when sign-in fails"
        )
    }

    func signIn() async {
        guard canSubmit else { return }

        failure = nil
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            try await session.login(email: email.trimmed, password: password)
        } catch {
            failure = LoadFailure.classify(error)
        }
    }
}

struct SignInView: View {

    @State private var viewModel: SignInViewModel
    @State private var isShowingSignUp = false

    let makeSignUpViewModel: () -> SignUpViewModel

    init(viewModel: SignInViewModel, makeSignUpViewModel: @escaping () -> SignUpViewModel) {
        _viewModel = State(wrappedValue: viewModel)
        self.makeSignUpViewModel = makeSignUpViewModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    EmailField(
                        text: $viewModel.email,
                        isRequired: true
                    )

                    PasswordField(
                        text: $viewModel.password,
                        isRequired: true
                    )

                    if let message = viewModel.signInErrorMessage {
                        InlineErrorText(message)
                    }

                    AsyncButton(
                        title: Text("Sign In", comment: "Button that submits the sign-in form"),
                        isRunning: viewModel.isSigningIn,
                        action: { await viewModel.signIn() }
                    )
                    .disabled(!viewModel.canSubmit)
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text("Gabay", comment: "Title of the sign-in screen"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSignUp = true
                    } label: {
                        Text("Sign Up", comment: "Opens the account creation screen")
                    }
                }
            }
            .sheet(isPresented: $isShowingSignUp) {
                SignUpView(viewModel: makeSignUpViewModel())
            }
        }
    }
}
