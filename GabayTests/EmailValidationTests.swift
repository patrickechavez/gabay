//
//  EmailValidationTests.swift
//  GabayTests
//

import Testing
@testable import Gabay

struct EmailValidationTests {

    @Test func acceptsAnOrdinaryAddress() {
        #expect("hiker@example.com".isValidEmail)
    }

    @Test func acceptsASubdomain() {
        #expect("organizer@mail.example.co.uk".isValidEmail)
    }

    @Test func rejectsAnEmptyString() {
        #expect("".isValidEmail == false)
    }

    @Test func rejectsAnAddressWithNoAtSign() {
        #expect("hiker.example.com".isValidEmail == false)
    }

    @Test func rejectsAnAddressWithTwoAtSigns() {
        #expect("hiker@example@com".isValidEmail == false)
    }

    @Test func rejectsAnEmptyLocalPart() {
        #expect("@example.com".isValidEmail == false)
    }

    @Test func rejectsADomainWithNoDot() {
        #expect("hiker@example".isValidEmail == false)
    }

    @Test func rejectsADomainThatStartsOrEndsWithADot() {
        #expect("hiker@.example.com".isValidEmail == false)
        #expect("hiker@example.com.".isValidEmail == false)
    }

    @Test func rejectsADomainWithConsecutiveDots() {
        #expect("hiker@example..com".isValidEmail == false)
    }

    @Test func rejectsAnAddressContainingASpace() {
        #expect("hiker @example.com".isValidEmail == false)
    }

    @Test func rejectsAnAddressLongerThanTheRFCLimit() {
        let local = String(repeating: "a", count: 250)
        #expect("\(local)@example.com".isValidEmail == false)
    }
}
