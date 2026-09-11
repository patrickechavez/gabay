//
//  FavoritesTab.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

struct FavoritesTab: View {

    @Environment(AppNavigator.self) private var navigator

    // The coordinator owns it — a route carries data in but no closure back out.
    @State private var favoriteNote = "Weekend trip"

    var body: some View {
        @Bindable var router = navigator.favorites

        NavigationStack(path: $router.path) {
            FavoritesView(note: $favoriteNote)
                .navigationDestination(for: FavoritesRoute.self) { route in
                    switch route {
                    case .favoriteDetail:
                        FavoriteDetailView()
                    case .favoriteNotes:
                        FavoriteNotesView()
                    case .favoriteSheet, .favoriteCover:
                        EmptyView()
                    }
                }
        }
        .environment(navigator.favorites)
        .appAlert($router.alert)
        .sheet(item: $router.sheet) { route in
            switch route {
            case let .favoriteSheet(note):
                FavoriteSheetView(note: note) { favoriteNote = $0 }
            case .favoriteDetail, .favoriteNotes, .favoriteCover:
                EmptyView()
            }
        }
        .fullScreenCover(item: $router.cover) { route in
            switch route {
            case .favoriteCover:
                FavoriteCoverView()
            case .favoriteDetail, .favoriteNotes, .favoriteSheet:
                EmptyView()
            }
        }
    }
}
