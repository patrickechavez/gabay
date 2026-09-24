//
//  Session.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

// The signed-in hiker, or lack of one. Every screen that cares who's signed in reads this.
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

    // Called once at launch; picks up a token already in the Keychain, or does nothing if there
    // isn't one.
    func restore() async {
        guard await tokenStore.load() != nil else { return }

        do {
            account = try await auth.me()
        } catch {
            // A transport failure (offline, timeout, 5xx) must not cost the user their session, so
            // only clear the store when the token is genuinely rejected. A 401 is normally handled
            // downstream by AuthInterceptor and TokenRefreshCoordinator, but classify here too in
            // case `me()` surfaces the rejection directly.
            if APIError.classify(error).invalidatesSession {
                await tokenStore.clear()
            }
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

    // Called by `TokenRefreshCoordinator.invalidate()` when a refresh fails or there's no refresh
    // token, so the session always reflects a rejected token no matter where it happened.
    func signOut() async {
        await tokenStore.clear()
        account = nil
    }
}
