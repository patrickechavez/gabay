//
//  AuthRepository.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
//

import Foundation

protocol AuthRepository: Sendable {

    func register(email: String, password: String) async throws -> AuthResult

    func login(email: String, password: String) async throws -> AuthResult

    func me() async throws -> Account
}

struct LiveAuthRepository: AuthRepository {

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
