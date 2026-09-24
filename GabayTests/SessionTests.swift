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
        let session = Session(auth: StubAuthenticating(), tokenStore: InMemoryTokenStore())
        #expect(session.isSignedIn == false)
    }

    @Test func restoreDoesNothingWithoutAStoredToken() async {
        let session = Session(auth: StubAuthenticating(), tokenStore: InMemoryTokenStore())
        await session.restore()
        #expect(session.isSignedIn == false)
    }

    @Test func restoreSignsInWhenATokenIsAlreadyStored() async throws {
        let auth = StubAuthenticating()
        auth.meResult = .success(hiker)
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save(AuthTokens(accessToken: "abc123"))

        let session = Session(auth: auth, tokenStore: tokenStore)
        await session.restore()

        #expect(session.account == hiker)
    }

    @Test func restoreClearsAStaleToken() async {
        let auth = StubAuthenticating()
        auth.meResult = .failure(APIError.unauthorized())
        let tokenStore = InMemoryTokenStore()
        try? await tokenStore.save(AuthTokens(accessToken: "stale"))

        let session = Session(auth: auth, tokenStore: tokenStore)
        await session.restore()

        #expect(session.isSignedIn == false)
        #expect(await tokenStore.load() == nil)
    }

    @Test func restoreKeepsTheTokenWhenMeFailsWithATransportError() async throws {
        let auth = StubAuthenticating()
        auth.meResult = .failure(APIError.offline)
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save(AuthTokens(accessToken: "abc123"))

        let session = Session(auth: auth, tokenStore: tokenStore)
        await session.restore()

        #expect(session.isSignedIn == false)
        #expect(await tokenStore.load() == AuthTokens(accessToken: "abc123"))
    }

    @Test func loginSavesTheTokenAndLoadsTheAccount() async throws {
        let auth = StubAuthenticating()
        auth.loginResult = .success(AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        auth.meResult = .success(hiker)
        let tokenStore = InMemoryTokenStore()

        let session = Session(auth: auth, tokenStore: tokenStore)
        try await session.login(email: hiker.email, password: "secret123")

        #expect(session.account == hiker)
        #expect(await tokenStore.load() == AuthTokens(accessToken: "abc123"))
    }

    @Test func signOutClearsEverything() async throws {
        let auth = StubAuthenticating()
        auth.loginResult = .success(AuthResult(accessToken: "abc123", refreshToken: nil, expiresAt: nil, role: .hiker))
        auth.meResult = .success(hiker)
        let tokenStore = InMemoryTokenStore()

        let session = Session(auth: auth, tokenStore: tokenStore)
        try await session.login(email: hiker.email, password: "secret123")

        await session.signOut()

        #expect(session.isSignedIn == false)
        #expect(await tokenStore.load() == nil)
    }
}
