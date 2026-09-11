//
//  FavoritesView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// First screen of the Favorites tab.
struct FavoritesView: View {

    // Owned by FavoritesTab, so the sheet's result has somewhere to land.
    @Binding var note: String

    @Environment(Router<FavoritesRoute>.self) private var router

    var body: some View {
        List {
            Button {
                router.push(.favoriteDetail)
            } label: {
                Label {
                    Text("Open a favorite", comment: "Row that opens the favorite detail screen")
                } icon: {
                    Image(systemName: "heart")
                }
            }

            Button {
                router.present(sheet: .favoriteSheet(note: note))
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Edit the note in a sheet", comment: "Row that presents the favorite sheet")

                        Text(note)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.secondaryText)
                    }
                } icon: {
                    Image(systemName: "square.and.pencil")
                }
            }

            Button {
                router.present(cover: .favoriteCover)
            } label: {
                Label {
                    Text("Open a full-screen cover", comment: "Row that presents the favorite full-screen cover")
                } icon: {
                    Image(systemName: "rectangle.on.rectangle")
                }
            }
        }
        .navigationTitle(Text("Favorites", comment: "Title of the favorites screen"))
    }
}

#if DEBUG

#Preview {
    NavigationStack {
        FavoritesView(note: .constant("Weekend trip"))
    }
    .environment(Router<FavoritesRoute>())
}

#endif
