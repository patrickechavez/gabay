//
//  Session.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

// The signed-in hiker, or the lack of one. Every screen that needs to know
// who's signed in, or what they're allowed to do, reads this.
@Observable
@MainActor
final class Session {

    private(set) var account: Account?

    var isSignedIn: Bool { account != nil }

    @ObservationIgnored private let auth: any Authenticating
    @ObservationIgnored private let tokenStore: any TokenStore

    init(auth: any Authenticating, tokenStore: any TokenStore) {
        self.auth = auth
        self.tokenStore = tokenStore
    }

    // Called once at launch. Picks up a token already in the Keychain, or
    // does nothing if there isn't one.
    func restore() async {
        guard await tokenStore.load() != nil else { return }

        do {
            account = try await auth.me()
        } catch {
            // A stale or revoked token: back to signed out.
            await tokenStore.clear()
        }
    }

    func register(email: String, password: String) async throws {
        let result = try await auth.register(email: email, password: password)
        try await tokenStore.save(result.tokens)
        account = try await auth.me()
    }

    func login(email: String, password: String) async throws {
        let result = try await auth.login(email: email, password: password)
        try await tokenStore.save(result.tokens)
        account = try await auth.me()
    }

    // Called by `TokenRefreshCoordinator.invalidate()` when a refresh fails
    // or there is no refresh token to try, so the session always reflects a
    // rejected token no matter where the rejection happened.
    func signOut() async {
        await tokenStore.clear()
        account = nil
    }
}
