//
//  TokenStoreTests.swift
//  GabayTests
//

import Foundation
import Security
import Testing
@testable import Gabay

struct TokenStoreTests {

    // A unique service per store, so one test's tokens never reach another
    // even when tests run concurrently against the real Keychain.
    private func makeService(_ label: String = #function) -> String {
        "com.patrick.Gabay.tests.\(label).\(UUID().uuidString)"
    }

    @Test func loadWithNothingStoredReturnsNil() async {
        let store = KeychainTokenStore(service: makeService())
        #expect(await store.load() == nil)
    }

    @Test func saveThenLoadRoundTrips() async throws {
        let store = KeychainTokenStore(service: makeService())
        let tokens = AuthTokens(
            accessToken: "abc123",
            refreshToken: "refresh456",
            expiresAt: Date(timeIntervalSince1970: 2_000_000_000)
        )

        try await store.save(tokens)

        #expect(await store.load() == tokens)
    }

    @Test func clearRemovesWhatWasStored() async throws {
        let store = KeychainTokenStore(service: makeService())
        try await store.save(AuthTokens(accessToken: "abc123"))

        await store.clear()

        #expect(await store.load() == nil)
    }

    @Test func aSecondSaveOverwritesRatherThanDuplicating() async throws {
        let store = KeychainTokenStore(service: makeService())
        try await store.save(AuthTokens(accessToken: "first"))
        try await store.save(AuthTokens(accessToken: "second"))

        #expect(await store.load() == AuthTokens(accessToken: "second"))
    }

    @Test func loadReturnsTheCachedValueWithoutASecondKeychainRead() async throws {
        let service = makeService()
        let store = KeychainTokenStore(service: service)
        let tokens = AuthTokens(accessToken: "abc123")
        try await store.save(tokens)

        // Delete the item directly from the Keychain, bypassing the store,
        // so any load that actually hits the Keychain now finds nothing.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "auth.tokens"
        ]
        SecItemDelete(query as CFDictionary)

        // The store still has its own cached answer...
        #expect(await store.load() == tokens)

        // ...while a fresh store pointed at the same service proves the
        // Keychain item is genuinely gone, so the first answer above could
        // only have come from the actor's cache, not a second read.
        let freshStore = KeychainTokenStore(service: service)
        #expect(await freshStore.load() == nil)
    }
}
