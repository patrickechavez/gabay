//
//  RouterTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

@MainActor
struct RouterTests {

    @Test func presentsAndDismissesASheet() {
        let router = Router<FavoritesRoute>()

        router.present(sheet: .favoriteSheet(note: "Weekend trip"))
        #expect(router.sheet == .favoriteSheet(note: "Weekend trip"))

        router.dismissSheet()
        #expect(router.sheet == nil)
    }

    @Test func presentsAndDismissesACover() {
        let router = Router<FavoritesRoute>()

        router.present(cover: .favoriteCover)
        #expect(router.cover == .favoriteCover)

        router.dismissCover()
        #expect(router.cover == nil)
    }

    @Test func keepsSheetAndCoverIndependent() {
        let router = Router<FavoritesRoute>()

        router.present(sheet: .favoriteSheet(note: "a"))
        router.present(cover: .favoriteCover)
        router.dismissSheet()

        #expect(router.sheet == nil)
        #expect(router.cover == .favoriteCover)
    }

    @Test func leavesModalsOutOfRestoration() throws {
        let router = Router<FavoritesRoute>()
        router.push(.favoriteDetail)
        router.present(sheet: .favoriteSheet(note: "a"))
        router.present(cover: .favoriteCover)

        let restored = Router<FavoritesRoute>()
        restored.restore(from: router.restorationData)

        #expect(restored.path == [.favoriteDetail])
        #expect(restored.sheet == nil)
        #expect(restored.cover == nil)
    }

    @Test func doesNotPresentAModalWhenPushing() {
        let router = Router<FavoritesRoute>()

        router.push(.favoriteDetail)

        #expect(router.sheet == nil)
        #expect(router.cover == nil)
    }
}
