//
//  AppRoute.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

protocol AppRoute: Hashable, Codable, Sendable, Identifiable {}

// Lets a route bind straight to .sheet(item:) and .fullScreenCover(item:).
extension AppRoute {
    var id: Self { self }
}

enum AppTab: String, Hashable, Codable, CaseIterable, Identifiable, Sendable {
    case home
    case favorites
    case profile
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "Items", comment: "Home tab title")
        case .favorites: String(localized: "Favorites", comment: "Favorites tab title")
        case .profile: String(localized: "Profile", comment: "Profile tab title")
        case .settings: String(localized: "Settings", comment: "Settings tab title")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "square.grid.2x2"
        case .favorites: "heart"
        case .profile: "person.crop.circle"
        case .settings: "gearshape"
        }
    }
}

enum AuthRoute: AppRoute {
    case register
    case forgotPassword
    case resetPassword(token: String)
}

// Each tab keeps its own route list, so its screens stack independently.
enum HomeRoute: AppRoute {
    case itemDetail(id: UUID)
    case itemReviews(id: UUID)
}

enum FavoritesRoute: AppRoute {
    case favoriteDetail
    case favoriteNotes
    // Carries its input; the result comes back through the coordinator.
    case favoriteSheet(note: String)
    case favoriteCover
}

enum ProfileRoute: AppRoute {
    case editProfile
    case changePassword
}

enum SettingsRoute: AppRoute {
    case notifications
    case blockedUsers
}
