//
//  FavoriteCoverView.swift
//  Gabay
//  Created by John Patrick Echavez on 9/9/26.
//

import SwiftUI

// The no-result case: a full-screen cover that only dismisses.
struct FavoriteCoverView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)

                Text("Covers the whole screen", comment: "Body of the favorite full-screen cover")
                    .foregroundStyle(Theme.Color.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle(Text("Full-Screen Cover", comment: "Title of the favorite full-screen cover"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close", comment: "Button that dismisses the favorite full-screen cover")
                    }
                }
            }
        }
    }
}

#if DEBUG

#Preview {
    FavoriteCoverView()
}

#endif
