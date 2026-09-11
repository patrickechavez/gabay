//
//  RootView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct RootView: View {

    let dependencies: AppDependencies

    var body: some View {
        TrailsPlaceholderView()
    }
}

// Stands in until the trail list is built.
struct TrailsPlaceholderView: View {

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Color.accent)

            Text(verbatim: "Gabay")
                .font(Theme.Font.screenTitle)

            Text("Trails that work without a signal",
                 comment: "One line saying what the app is for")
                .font(Theme.Font.secondary)
                .foregroundStyle(Theme.Color.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Color.background)
    }
}

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Starting up", comment: "Accessibility label for the launch screen"))
    }
}
