//
//  RootView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct RootView: View {

    let dependencies: AppDependencies

    var body: some View {
        TabView {
            TrailsView(viewModel: dependencies.makeTrailsViewModel(), recorder: dependencies.recorder)
                .tabItem {
                    Label {
                        Text("Trails", comment: "Title of the trail list")
                    } icon: {
                        Image(systemName: "mountain.2")
                    }
                }

            RecordView(recorder: dependencies.recorder)
                .tabItem {
                    Label {
                        Text("Record", comment: "Title of the recording tab")
                    } icon: {
                        Image(systemName: "record.circle")
                    }
                }

            HistoryView(viewModel: dependencies.makeHistoryViewModel())
                .tabItem {
                    Label {
                        Text("History", comment: "Title of the saved walks tab")
                    } icon: {
                        Image(systemName: "clock")
                    }
                }
        }
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
