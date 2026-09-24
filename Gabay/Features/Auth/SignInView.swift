//
//  SignInView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import SwiftUI

@Observable
@MainActor
final class SignInViewModel {

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

    init(session: Session) {
        self.session = session
    }

    // Sign-in deliberately has no inline field validation. A local rule here
    // would gate canSubmit, and a false negative would lock someone out of
    // their own account over an unusual but legal address. The server decides.
    var canSubmit: Bool {
        !email.trimmed.isEmpty && !password.isEmpty && !action.isRunning
    }

    // Unguarded, unlike its sign-up and post-event siblings: sign-in renders
    // no field slots at all, so every validation error belongs here.
    var signInErrorMessage: String? {
        action.errorMessage
    }

    func signIn() async {
        guard canSubmit else { return }

        let credentials = (email: email.trimmed, password: password)
        await action.run { [session] in
            try await session.login(email: credentials.email, password: credentials.password)
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
                        isRunning: viewModel.action.isRunning,
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
