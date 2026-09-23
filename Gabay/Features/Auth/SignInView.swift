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

    var isShowingFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isSigningIn
    }

    func signIn() async {
        guard canSubmit else { return }

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            try await session.login(email: email, password: password)
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
            Form {
                Section {
                    TextField(
                        "Email",
                        text: $viewModel.email,
                        prompt: Text("Email", comment: "Placeholder for the sign-in email field")
                    )
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)

                    SecureField(
                        "Password",
                        text: $viewModel.password,
                        prompt: Text("Password", comment: "Placeholder for the sign-in password field")
                    )
                    .textContentType(.password)
                }

                Section {
                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        if viewModel.isSigningIn {
                            ProgressView()
                        } else {
                            Text("Sign In", comment: "Button that submits the sign-in form")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
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
            .alert(
                Text("Couldn't sign in", comment: "Title when sign-in fails"),
                isPresented: $viewModel.isShowingFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the sign-in failure alert")
                }
            } message: {
                Text("Check your email and password, then try again.",
                     comment: "Shown when sign-in fails")
            }
        }
    }
}
