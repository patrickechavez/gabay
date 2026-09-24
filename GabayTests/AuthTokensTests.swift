//
//  AuthTokensTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct AuthTokensTests {

    // MARK: isExpired

    @Test func isExpiredIsFalseWhenThereIsNoExpiry() {
        let tokens = AuthTokens(accessToken: "abc123", expiresAt: nil)
        #expect(tokens.isExpired == false)
    }

    @Test func isExpiredIsTrueWhenExpiryIsInThePast() {
        let tokens = AuthTokens(accessToken: "abc123", expiresAt: Date().addingTimeInterval(-10))
        #expect(tokens.isExpired)
    }

    @Test func isExpiredIsFalseWhenExpiryIsInTheFuture() {
        let tokens = AuthTokens(accessToken: "abc123", expiresAt: Date().addingTimeInterval(1_000))
        #expect(tokens.isExpired == false)
    }

    // MARK: needsProactiveRefresh

    @Test func needsProactiveRefreshIsFalseWhenThereIsNoExpiry() {
        let tokens = AuthTokens(accessToken: "abc123", expiresAt: nil)
        #expect(tokens.needsProactiveRefresh == false)
    }

    @Test func needsProactiveRefreshIsTrueInsideTheSixtySecondWindow() {
        let tokens = AuthTokens(accessToken: "abc123", expiresAt: Date().addingTimeInterval(30))
        #expect(tokens.needsProactiveRefresh)
    }

    @Test func needsProactiveRefreshIsFalseOutsideTheSixtySecondWindow() {
        let tokens = AuthTokens(accessToken: "abc123", expiresAt: Date().addingTimeInterval(120))
        #expect(tokens.needsProactiveRefresh == false)
    }

    // MARK: canRefresh

    @Test func canRefreshIsFalseWhenThereIsNoRefreshToken() {
        let tokens = AuthTokens(accessToken: "abc123", refreshToken: nil)
        #expect(tokens.canRefresh == false)
    }

    @Test func canRefreshIsFalseWhenTheRefreshTokenIsEmpty() {
        let tokens = AuthTokens(accessToken: "abc123", refreshToken: "")
        #expect(tokens.canRefresh == false)
    }

    @Test func canRefreshIsTrueWhenThereIsARefreshToken() {
        let tokens = AuthTokens(accessToken: "abc123", refreshToken: "refresh456")
        #expect(tokens.canRefresh)
    }
}
