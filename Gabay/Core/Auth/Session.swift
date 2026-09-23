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
    @ObservationIgnored private let tokenStore: any TokenStoring

    init(auth: any Authenticating, tokenStore: any TokenStoring) {
        self.auth = auth
        self.tokenStore = tokenStore
    }

    // Called once at launch. Picks up a token already in the Keychain, or
    // does nothing if there isn't one.
    func restore() async {
        guard tokenStore.load() != nil else { return }

        do {
            account = try await auth.me()
        } catch {
            // A stale or revoked token: back to signed out.
            tokenStore.clear()
        }
    }

    func register(email: String, password: String) async throws {
        let result = try await auth.register(email: email, password: password)
        try tokenStore.save(result.token)
        account = try await auth.me()
    }

    func login(email: String, password: String) async throws {
        let result = try await auth.login(email: email, password: password)
        try tokenStore.save(result.token)
        account = try await auth.me()
    }

    // Called by any view model after a 401, not just from within Session,
    // so a session always reflects a rejected token no matter where it was
    // rejected.
    func signOut() {
        tokenStore.clear()
        account = nil
    }
}
