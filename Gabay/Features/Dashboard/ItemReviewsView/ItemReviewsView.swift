//
//  ItemReviewsView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

// Third screen of the Home tab.
struct ItemReviewsView: View {

    let itemID: UUID

    @Environment(Router<HomeRoute>.self) private var router

    var body: some View {
        List {
            Text("Reviews for item \(itemID)", comment: "Placeholder line on the item reviews screen")
                .foregroundStyle(.secondary)

            // Clears every screen in this tab only; other tabs stay put.
            Button {
                router.popToRoot()
            } label: {
                Text("Back to Root", comment: "Button that returns to the first screen of the tab")
            }
        }
        .navigationTitle(Text("Reviews", comment: "Title of the item reviews screen"))
    }
}
