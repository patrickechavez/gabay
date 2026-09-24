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
        SignUpViewModel(session: Session(auth: StubAuthRepository(), tokenStore: InMemoryTokenStore()))
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

    @Test func aWhitespaceOnlyEmailShowsNoError() {
        let viewModel = makeViewModel()
        viewModel.email = "   "
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
        let auth = StubAuthRepository()
        auth.registerResult = .success(AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        let tokenStore = InMemoryTokenStore()
        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: tokenStore))

        let result = await viewModel.register()

        #expect(result == false)
        #expect(viewModel.action.error == nil)
        #expect(await tokenStore.load() == nil)
    }

    @Test func registerTrimsTheEmailBeforeSendingIt() async {
        let auth = StubAuthRepository()
        auth.registerResult = .success(AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))

        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: InMemoryTokenStore()))
        viewModel.email = "  hiker@example.com  "
        viewModel.password = "longenough"

        #expect(await viewModel.register())
        #expect(auth.registeredEmail == "hiker@example.com")
    }

    @Test func registerReturnsTrueOnASuccessfulRegistration() async {
        let auth = StubAuthRepository()
        auth.registerResult = .success(AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))

        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: InMemoryTokenStore()))
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
        let auth = StubAuthRepository()
        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: InMemoryTokenStore()))
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"

        _ = await viewModel.register()
        #expect(viewModel.signUpErrorMessage != nil)

        auth.registerResult = .success(AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        auth.meResult = .success(Account(email: "hiker@example.test", role: .hiker))
        _ = await viewModel.register()

        #expect(viewModel.signUpErrorMessage == nil)
    }

    @Test func aServerFieldMessageWinsOverTheLocalRule() async {
        let auth = StubAuthRepository()
        auth.registerResult = .failure(APIError.validation(ValidationErrors(
            fields: ["email": ["That email is already registered."]],
            summary: nil
        )))
        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: InMemoryTokenStore()))
        // Well-formed, so the local rule alone would say nothing here.
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"

        _ = await viewModel.register()

        #expect(viewModel.emailError == "That email is already registered.")
    }

    @Test func aValidationErrorOnAFieldWithNoSlotShowsTheWholeFormMessage() async {
        let auth = StubAuthRepository()
        auth.registerResult = .failure(APIError.validation(ValidationErrors(
            fields: ["captcha": ["Please complete the challenge."]],
            summary: nil
        )))
        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: InMemoryTokenStore()))
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"

        _ = await viewModel.register()

        #expect(viewModel.signUpErrorMessage != nil)
    }

    @Test func aValidationErrorOnlyOnFieldsWithSlotsSuppressesTheWholeFormMessage() async {
        let auth = StubAuthRepository()
        auth.registerResult = .failure(APIError.validation(ValidationErrors(
            fields: ["email": ["That email is already registered."]],
            summary: nil
        )))
        let viewModel = SignUpViewModel(session: Session(auth: auth, tokenStore: InMemoryTokenStore()))
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"

        _ = await viewModel.register()

        #expect(viewModel.signUpErrorMessage == nil)
    }

    @Test func editingAFieldAfterAFailedRegistrationClearsTheStaleMessage() async {
        let viewModel = makeViewModel()
        viewModel.email = "hiker@example.com"
        viewModel.password = "longenough"

        _ = await viewModel.register()
        #expect(viewModel.signUpErrorMessage != nil)

        // canSubmit goes false, so nothing resubmits to clear the message; the edit itself has to clear it.
        viewModel.password = "short"

        #expect(viewModel.canSubmit == false)
        #expect(viewModel.signUpErrorMessage == nil)
    }
}
