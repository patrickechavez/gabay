//
//  RootView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct RootView: View {

    let dependencies: AppDependencies

    var body: some View {
        TrailsView(viewModel: dependencies.makeTrailsViewModel())
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
