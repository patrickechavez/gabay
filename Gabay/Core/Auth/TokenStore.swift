//
//  TokenStore.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation
import Security

// Where the signed-in hiker's session token lives. The Keychain survives
// reinstalls and app updates, unlike UserDefaults, which is where a token
// belongs.
protocol TokenStoring: Sendable {

    func save(_ token: String) throws

    func load() -> String?

    func clear()
}

struct TokenStore: TokenStoring {

    private let service: String
    private let account = "session-token"

    // The service is a parameter so a test can use its own, and never
    // collide with the token a real sign-in left behind.
    init(service: String = "com.patrick.Gabay.session") {
        self.service = service
    }

    func save(_ token: String) throws {
        clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8)
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw TokenStoreError.saveFailed(status) }
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum TokenStoreError: Error, Equatable {
    case saveFailed(OSStatus)
}
