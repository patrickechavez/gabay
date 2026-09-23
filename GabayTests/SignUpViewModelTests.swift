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
}
