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

    // Backed by its own storage with a hand-written setter (not a plain stored property) so every
    // edit clears a stale failure via `ActionState.clear()`, instead of leaving it on screen until
    // a resubmit a bad edit might never allow.
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

    // Sign-in deliberately has no inline field validation: a local rule could false-negative and
    // lock someone out of their own account over an unusual but legal address. The server decides.
    var canSubmit: Bool {
        !email.trimmed.isEmpty && !password.isEmpty && !action.isRunning
    }

    // Unguarded, unlike its sign-up and post-event siblings: sign-in renders no field slots at all,
    // so every validation error belongs here.
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
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                VStack(spacing: Theme.Spacing.sm) {
                    BrandMark()
                        .frame(width: Theme.Size.brandMark, height: Theme.Size.brandMark)

                    Text(
                        "Gabay",
                        comment: "The app's name, shown under the mark on the sign-in screen"
                    )
                    .font(Theme.Font.sectionTitle)
                    .foregroundStyle(Theme.Color.brand)
                }
                .padding(.bottom, Theme.Spacing.md)

                EmailField(text: $viewModel.email)

                PasswordField(text: $viewModel.password)

                if let message = viewModel.signInErrorMessage {
                    InlineErrorText(message)
                }

                AsyncButton(
                    title: Text("Sign In", comment: "Button that submits the sign-in form"),
                    isRunning: viewModel.action.isRunning,
                    action: { await viewModel.signIn() }
                )
                .disabled(!viewModel.canSubmit)

                HStack(spacing: Theme.Spacing.xs) {
                    Text(
                        "New to Gabay?",
                        comment: "Precedes the sign-up link on the sign-in screen"
                    )
                    .foregroundStyle(Theme.Color.secondaryText)

                    Button {
                        isShowingSignUp = true
                    } label: {
                        Text("Sign Up", comment: "Opens the account creation screen")
                    }
                }
                .font(Theme.Font.secondary)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: Theme.Size.formMaxWidth)
            // The wider frame centres the clamped one; the container frame fills the scroll view's
            // height so a short form sits in the middle instead of riding the top edge.
            .frame(maxWidth: .infinity)
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $isShowingSignUp) {
            SignUpView(viewModel: makeSignUpViewModel())
        }
    }
}
