//
//  TokenStoreTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct TokenStoreTests {

    // A service per test, so one test's token never reaches another.
    private func makeStore() -> TokenStore {
        TokenStore(service: "com.patrick.Gabay.tests.\(UUID().uuidString)")
    }

    @Test func startsWithNothing() {
        let store = makeStore()
        #expect(store.load() == nil)
    }

    @Test func givesBackWhatItWasGiven() throws {
        let store = makeStore()
        try store.save("abc123")
        #expect(store.load() == "abc123")
    }

    @Test func replacesWhatWasThereBefore() throws {
        let store = makeStore()
        try store.save("first")
        try store.save("second")
        #expect(store.load() == "second")
    }

    @Test func forgetsAfterClear() throws {
        let store = makeStore()
        try store.save("abc123")
        store.clear()
        #expect(store.load() == nil)
    }
}
