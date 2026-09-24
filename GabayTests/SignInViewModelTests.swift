//
//  SignInViewModelTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct SignInViewModelTests {

    private func makeViewModel() -> SignInViewModel {
        SignInViewModel(session: Session(auth: StubAuthRepository(), tokenStore: InMemoryTokenStore()))
    }

    @Test func cannotSubmitAnEmptyForm() {
        #expect(makeViewModel().canSubmit == false)
    }

    @Test func cannotSubmitWithOnlyEmailFilled() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        #expect(viewModel.canSubmit == false)
    }

    @Test func cannotSubmitWithOnlyPasswordFilled() {
        let viewModel = makeViewModel()
        viewModel.password = "whatever"
        #expect(viewModel.canSubmit == false)
    }

    @Test func canSubmitOnceBothFieldsAreFilled() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "whatever"
        #expect(viewModel.canSubmit)
    }

    @Test func signInErrorMessageIsNilInitially() {
        #expect(makeViewModel().signInErrorMessage == nil)
    }

    @Test func signInErrorMessageIsSetAfterAFailedSignIn() async {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "whatever"

        await viewModel.signIn()

        #expect(viewModel.signInErrorMessage != nil)
    }

    @Test func aSecondSignInAttemptClearsTheFailureFromTheFirst() async {
        let auth = StubAuthRepository()
        let viewModel = SignInViewModel(session: Session(auth: auth, tokenStore: InMemoryTokenStore()))
        viewModel.email = "hiker@example.com"
        viewModel.password = "whatever"

        await viewModel.signIn()
        #expect(viewModel.signInErrorMessage != nil)

        auth.loginResult = .success(AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        await viewModel.signIn()

        #expect(viewModel.signInErrorMessage == nil)
    }

    @Test func editingAFieldAfterAFailedSignInClearsTheStaleMessage() async {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "whatever"

        await viewModel.signIn()
        #expect(viewModel.signInErrorMessage != nil)

        // canSubmit goes false, so nothing resubmits to clear the message; the edit itself has to clear it.
        viewModel.password = ""

        #expect(viewModel.canSubmit == false)
        #expect(viewModel.signInErrorMessage == nil)
    }

    @Test func signInTrimsTheEmailBeforeSendingIt() async {
        let auth = StubAuthRepository()
        auth.loginResult = .success(AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))

        let viewModel = SignInViewModel(session: Session(auth: auth, tokenStore: InMemoryTokenStore()))
        viewModel.email = "  hiker@example.com  "
        viewModel.password = "whatever"

        await viewModel.signIn()

        #expect(auth.loggedInEmail == "hiker@example.com")
    }
}
