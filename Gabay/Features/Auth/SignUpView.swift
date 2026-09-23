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

    init(session: Session) {
        self.session = session
    }

    var isShowingFailure: Bool {
        get { failure != nil }
        set { if !newValue { failure = nil } }
    }

    // A backend-defined minimum; the form just avoids an obviously-too-short
    // password making a wasted round trip.
    var canSubmit: Bool {
        !email.isEmpty && password.count >= 8 && !isRegistering
    }

    func register() async -> Bool {
        guard canSubmit else { return false }

        isRegistering = true
        defer { isRegistering = false }

        do {
            try await session.register(email: email, password: password)
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
            Form {
                Section {
                    TextField(
                        "Email",
                        text: $viewModel.email,
                        prompt: Text("Email", comment: "Placeholder for the sign-up email field")
                    )
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)

                    SecureField(
                        "Password",
                        text: $viewModel.password,
                        prompt: Text("Password", comment: "Placeholder for the sign-up password field")
                    )
                    .textContentType(.newPassword)
                } footer: {
                    Text("At least 8 characters.", comment: "Password requirement shown under the field")
                }

                Section {
                    Button {
                        Task {
                            if await viewModel.register() { dismiss() }
                        }
                    } label: {
                        if viewModel.isRegistering {
                            ProgressView()
                        } else {
                            Text("Create Account", comment: "Button that submits the sign-up form")
                        }
                    }
                    .disabled(!viewModel.canSubmit)
                }
            }
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
            .alert(
                Text("Couldn't create account", comment: "Title when sign-up fails"),
                isPresented: $viewModel.isShowingFailure
            ) {
                Button {
                } label: {
                    Text("OK", comment: "Dismisses the sign-up failure alert")
                }
            } message: {
                Text("Try again in a moment.", comment: "Shown when sign-up fails")
            }
        }
    }
}
