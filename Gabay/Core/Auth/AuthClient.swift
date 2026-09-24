//
//  AuthClient.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

enum AccountRole: String, Codable, Sendable {
    case hiker
    case organizer
}

struct Account: Codable, Equatable, Sendable {
    let email: String
    let role: AccountRole
}

struct AuthResult: Codable, Equatable, Sendable {
    let token: String
    let role: AccountRole
}

// Registers, signs in, and reads the signed-in account.
protocol Authenticating: Sendable {

    func register(email: String, password: String) async throws -> AuthResult

    func login(email: String, password: String) async throws -> AuthResult

    func me() async throws -> Account
}

struct AuthClient: Authenticating {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func register(email: String, password: String) async throws -> AuthResult {
        try await api.post(
            APIRoute.Auth.register,
            body: Credentials(email: email, password: password),
            requiresAuth: false
        )
    }

    func login(email: String, password: String) async throws -> AuthResult {
        try await api.post(
            APIRoute.Auth.login,
            body: Credentials(email: email, password: password),
            requiresAuth: false
        )
    }

    func me() async throws -> Account {
        try await api.get(APIRoute.Auth.currentUser)
    }

    private struct Credentials: Encodable {
        let email: String
        let password: String
    }
}
