//
//  TestDoubles.swift
//  GabayTests
//

import Foundation
@testable import Gabay

// Shared stand-ins for the protocols view models depend on, so tests don't
// need a network or a Keychain to drive them.

final class StubAuthenticating: Authenticating, @unchecked Sendable {
    var registerResult: Result<AuthResult, any Error> = .failure(APIError.unauthorized)
    var loginResult: Result<AuthResult, any Error> = .failure(APIError.unauthorized)
    var meResult: Result<Account, any Error> = .failure(APIError.unauthorized)

    func register(email: String, password: String) async throws -> AuthResult {
        try registerResult.get()
    }

    func login(email: String, password: String) async throws -> AuthResult {
        try loginResult.get()
    }

    func me() async throws -> Account {
        try meResult.get()
    }
}

final class StubTokenStore: TokenStoring, @unchecked Sendable {
    private(set) var saved: String?

    func save(_ token: String) throws { saved = token }
    func load() -> String? { saved }
    func clear() { saved = nil }
}
