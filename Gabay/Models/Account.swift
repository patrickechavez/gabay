//
//  Account.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
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
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let role: AccountRole

    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }
}
