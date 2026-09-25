//
//  RootView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct RootView: View {

    let dependencies: AppDependencies

    var body: some View {
        Group {
            if dependencies.session.isSignedIn {
                SignedInView(dependencies: dependencies)
            } else {
                SignInView(
                    viewModel: dependencies.makeSignInViewModel(),
                    makeSignUpViewModel: dependencies.makeSignUpViewModel
                )
            }
        }
        .offlineBanner(dependencies.networkMonitor)
        .task { await dependencies.session.restore() }
    }
}

struct SignedInView: View {

    let dependencies: AppDependencies

    var body: some View {
        TabView {
            EventsListView(viewModel: dependencies.eventsViewModel)
                .tabItem {
                    Label {
                        Text("Events", comment: "Tab title for the list of cause-hike events")
                    } icon: {
                        Image(systemName: "figure.hiking")
                    }
                }

            MyEventsView(viewModel: dependencies.eventsViewModel)
                .tabItem {
                    Label {
                        Text("My Events", comment: "Tab title for events the hiker has joined")
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                }

            if dependencies.session.account?.role == .organizer {
                PostEventView(viewModel: dependencies.makePostEventViewModel())
                    .tabItem {
                        Label {
                            Text("Post a Hike", comment: "Tab title for the organizer event-creation form")
                        } icon: {
                            Image(systemName: "plus.circle")
                        }
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
