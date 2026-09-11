//
//  LoginViewModelTests.swift
//  GabayTests
//

import Testing
@testable import Gabay

@MainActor
struct LoginViewModelTests {

    // Wires a LoginViewModel to fresh mocks, so every test starts clean.
    private func makeViewModel(auth: MockAuthRepository = MockAuthRepository()) -> LoginViewModel {
        let session = SessionManager(
            tokenStore: InMemoryTokenStore(),
            users: MockUserRepository()
        )
        return LoginViewModel(auth: auth, session: session)
    }

    // MARK: - canSubmit

    @Test func blocksSubmitWhenEmailIsEmpty() {
        let viewModel = makeViewModel()
        viewModel.email = ""
        viewModel.password = "hunter2"

        #expect(!viewModel.canSubmit)
    }

    @Test func blocksSubmitWhenPasswordIsEmpty() {
        let viewModel = makeViewModel()
        viewModel.email = "raven@example.com"
        viewModel.password = ""

        #expect(!viewModel.canSubmit)
    }

    @Test func allowsSubmitWhenBothFieldsAreFilled() {
        let viewModel = makeViewModel()
        viewModel.email = "raven@example.com"
        viewModel.password = "hunter2"

        #expect(viewModel.canSubmit)
    }

    // MARK: - Happy path

    @Test func successfulLoginClearsThePassword() async {
        let viewModel = makeViewModel()
        viewModel.email = "raven@example.com"
        viewModel.password = "hunter2"

        await viewModel.signIn()

        #expect(viewModel.password.isEmpty)
    }

    @Test func successfulLoginAuthenticatesTheSession() async {
        let auth = MockAuthRepository()
        let session = SessionManager(
            tokenStore: InMemoryTokenStore(),
            users: MockUserRepository()
        )
        let viewModel = LoginViewModel(auth: auth, session: session)
        viewModel.email = "raven@example.com"
        viewModel.password = "hunter2"

        await viewModel.signIn()

        #expect(session.state == .authenticated)
    }

    @Test func trimsWhitespaceFromTheEmailBeforeSendingIt() async {
        let auth = MockAuthRepository()
        let viewModel = makeViewModel(auth: auth)
        viewModel.email = "  raven@example.com  "
        viewModel.password = "hunter2"

        await viewModel.signIn()

        #expect(auth.lastLoginUsername == "raven@example.com")
    }

    // MARK: - Failure path

    @Test func emailValidationErrorSurfacesOnTheEmailField() async {
        let auth = MockAuthRepository()
        auth.loginResult = .failure(.validation(ValidationErrors(
            fields: ["email": ["No account with that email."]],
            summary: nil
        )))
        let viewModel = makeViewModel(auth: auth)
        viewModel.email = "ghost@example.com"
        viewModel.password = "hunter2"

        await viewModel.signIn()

        #expect(viewModel.emailError == "No account with that email.")
    }

    @Test func passwordValidationErrorSurfacesOnThePasswordField() async {
        let auth = MockAuthRepository()
        auth.loginResult = .failure(.validation(ValidationErrors(
            fields: ["password": ["Incorrect password."]],
            summary: nil
        )))
        let viewModel = makeViewModel(auth: auth)
        viewModel.email = "raven@example.com"
        viewModel.password = "wrong"

        await viewModel.signIn()

        #expect(viewModel.passwordError == "Incorrect password.")
    }

    @Test func nonValidationFailureSurfacesAsAGeneralError() async {
        let auth = MockAuthRepository()
        auth.loginResult = .failure(.unauthorized())
        let viewModel = makeViewModel(auth: auth)
        viewModel.email = "raven@example.com"
        viewModel.password = "hunter2"

        await viewModel.signIn()

        #expect(viewModel.generalError != nil)
    }

    @Test func generalErrorIsSuppressedWhenFieldErrorsExist() async {
        let auth = MockAuthRepository()
        auth.loginResult = .failure(.validation(ValidationErrors(
            fields: ["email": ["No account with that email."]],
            summary: nil
        )))
        let viewModel = makeViewModel(auth: auth)
        viewModel.email = "ghost@example.com"
        viewModel.password = "hunter2"

        await viewModel.signIn()

        #expect(viewModel.generalError == nil)
    }

    // MARK: - Guard rails

    @Test func signInDoesNothingWhenCanSubmitIsFalse() async {
        let auth = MockAuthRepository()
        let viewModel = makeViewModel(auth: auth)
        viewModel.email = ""
        viewModel.password = ""

        await viewModel.signIn()

        #expect(auth.loginCallCount == 0)
    }

    @Test func aSecondSubmitWhileTheFirstIsRunningIsIgnored() async {
        let auth = MockAuthRepository()
        let viewModel = makeViewModel(auth: auth)
        viewModel.email = "raven@example.com"
        viewModel.password = "hunter2"

        async let first: Void = viewModel.signIn()
        async let second: Void = viewModel.signIn()
        _ = await (first, second)

        #expect(auth.loginCallCount == 1)
    }
}
