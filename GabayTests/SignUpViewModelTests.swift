//
//  SignUpViewModelTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct SignUpViewModelTests {

    private func makeViewModel() -> SignUpViewModel {
        SignUpViewModel(session: Session(auth: StubAuthenticating(), tokenStore: StubTokenStore()))
    }

    @Test func anUntouchedEmailShowsNoError() {
        #expect(makeViewModel().emailError == nil)
    }

    @Test func aMalformedEmailShowsAnError() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example"
        #expect(viewModel.emailError != nil)
    }

    @Test func aWellFormedEmailShowsNoError() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        #expect(viewModel.emailError == nil)
    }

    @Test func anUntouchedPasswordShowsNoError() {
        #expect(makeViewModel().passwordError == nil)
    }

    @Test func aShortPasswordShowsAnError() {
        let viewModel = makeViewModel()
        viewModel.password = "short"
        #expect(viewModel.passwordError != nil)
    }

    @Test func aLongEnoughPasswordShowsNoError() {
        let viewModel = makeViewModel()
        viewModel.password = "longenough"
        #expect(viewModel.passwordError == nil)
    }

    @Test func aPasswordOneCharacterBelowTheMinimumShowsAnError() {
        let viewModel = makeViewModel()
        viewModel.password = "abcdefg"
        #expect(viewModel.passwordError != nil)
    }

    @Test func aPasswordOneCharacterBelowTheMinimumCannotSubmit() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "abcdefg"
        #expect(viewModel.canSubmit == false)
    }

    @Test func aPasswordAtTheMinimumLengthShowsNoError() {
        let viewModel = makeViewModel()
        viewModel.password = "abcdefgh"
        #expect(viewModel.passwordError == nil)
    }

    @Test func aPasswordAtTheMinimumLengthCanSubmit() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "abcdefgh"
        #expect(viewModel.canSubmit)
    }

    @Test func cannotSubmitAnEmptyForm() {
        #expect(makeViewModel().canSubmit == false)
    }

    @Test func cannotSubmitWithAMalformedEmail() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example"
        viewModel.password = "longenough"
        #expect(viewModel.canSubmit == false)
    }

    @Test func cannotSubmitWithAShortPassword() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "short"
        #expect(viewModel.canSubmit == false)
    }

    @Test func canSubmitOnceBothFieldsAreValid() {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"
        #expect(viewModel.canSubmit)
    }

    @Test func registerDoesNothingWhenTheFormCannotBeSubmitted() async {
        let auth = StubAuthenticating()
        auth.registerResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        let tokenStore = StubTokenStore()
        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: tokenStore))

        let result = await viewModel.register()

        #expect(result == false)
        #expect(viewModel.failure == nil)
        #expect(tokenStore.saved == nil)
    }

    @Test func registerTrimsTheEmailBeforeSendingIt() async {
        let auth = StubAuthenticating()
        auth.registerResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))

        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: StubTokenStore()))
        viewModel.email = "  hiker@example.com  "
        viewModel.password = "longenough"

        #expect(await viewModel.register())
        #expect(auth.registeredEmail == "hiker@example.com")
    }

    @Test func registerReturnsTrueOnASuccessfulRegistration() async {
        let auth = StubAuthenticating()
        auth.registerResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))

        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: StubTokenStore()))
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"

        #expect(await viewModel.register())
    }

    @Test func registerReturnsFalseAndSetsAnErrorMessageOnFailure() async {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"

        let result = await viewModel.register()

        #expect(result == false)
        #expect(viewModel.signUpErrorMessage != nil)
    }

    @Test func aSecondRegisterAttemptClearsTheFailureFromTheFirst() async {
        let auth = StubAuthenticating()
        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: StubTokenStore()))
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"

        _ = await viewModel.register()
        #expect(viewModel.signUpErrorMessage != nil)

        auth.registerResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        _ = await viewModel.register()

        #expect(viewModel.signUpErrorMessage == nil)
    }
}
