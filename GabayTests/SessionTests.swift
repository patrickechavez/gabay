//
//  SessionTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct SessionTests {

    private let hiker = Account(email: "hiker@example.test", role: .hiker)

    @Test func startsSignedOut() {
        let session = Session(auth: StubAuthenticating(), tokenStore: StubTokenStore())
        #expect(session.isSignedIn == false)
    }

    @Test func restoreDoesNothingWithoutAStoredToken() async {
        let session = Session(auth: StubAuthenticating(), tokenStore: StubTokenStore())
        await session.restore()
        #expect(session.isSignedIn == false)
    }

    @Test func restoreSignsInWhenATokenIsAlreadyStored() async throws {
        let auth = StubAuthenticating()
        auth.meResult = .success(hiker)
        let tokenStore = StubTokenStore()
        try tokenStore.save("abc123")

        let session = Session(auth: auth, tokenStore: tokenStore)
        await session.restore()

        #expect(session.account == hiker)
    }

    @Test func restoreClearsAStaleToken() async {
        let auth = StubAuthenticating()
        auth.meResult = .failure(APIError.unauthorized)
        let tokenStore = StubTokenStore()
        try? tokenStore.save("stale")

        let session = Session(auth: auth, tokenStore: tokenStore)
        await session.restore()

        #expect(session.isSignedIn == false)
        #expect(tokenStore.load() == nil)
    }

    @Test func loginSavesTheTokenAndLoadsTheAccount() async throws {
        let auth = StubAuthenticating()
        auth.loginResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(hiker)
        let tokenStore = StubTokenStore()

        let session = Session(auth: auth, tokenStore: tokenStore)
        try await session.login(email: hiker.email, password: "secret123")

        #expect(session.account == hiker)
        #expect(tokenStore.load() == "abc123")
    }

    @Test func signOutClearsEverything() async throws {
        let auth = StubAuthenticating()
        auth.loginResult = .success(AuthResult(token: "abc123", role: .hiker))
        auth.meResult = .success(hiker)
        let tokenStore = StubTokenStore()

        let session = Session(auth: auth, tokenStore: tokenStore)
        try await session.login(email: hiker.email, password: "secret123")

        session.signOut()

        #expect(session.isSignedIn == false)
        #expect(tokenStore.load() == nil)
    }
}
