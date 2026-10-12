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
            if dependencies.session.isRestoring {
                LaunchView()
            } else if dependencies.session.isSignedIn {
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
        .onOpenURL { url in
            dependencies.navigator.open(url, isSignedIn: dependencies.session.isSignedIn)
        }
        // A link that arrived while signed out was held, not dropped; play it now.
        .onChange(of: dependencies.session.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                dependencies.navigator.resumePendingLink()
            } else {
                dependencies.navigator.reset()
            }
        }
        // The Post a Hike tab disappears with the organizer role, taking its tag with it.
        .onChange(of: dependencies.session.account?.role) { _, role in
            if role != .organizer { dependencies.navigator.leavePostEventTabIfPresent() }
        }
    }
}

struct SignedInView: View {

    let dependencies: AppDependencies

    var body: some View {
        TabView(selection: Bindable(dependencies.navigator).tab) {
            EventsListView(
                viewModel: dependencies.eventsViewModel,
                router: dependencies.navigator.events
            )
            .tabItem { label(for: .events) }
            .tag(AppTab.events)

            MyEventsView(
                viewModel: dependencies.eventsViewModel,
                router: dependencies.navigator.myEvents
            )
            .tabItem { label(for: .myEvents) }
            .tag(AppTab.myEvents)

            if dependencies.session.account?.role == .organizer {
                PostEventView(viewModel: dependencies.makePostEventViewModel())
                    .tabItem { label(for: .postEvent) }
                    .tag(AppTab.postEvent)
            }
        }
    }

    // Title and icon live on AppTab, so a tab and the deep link that selects it cannot disagree.
    private func label(for tab: AppTab) -> some View {
        Label {
            Text(tab.title)
        } icon: {
            Image(systemName: tab.systemImage)
        }
    }
}

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()

            VStack(spacing: Theme.Spacing.md) {
                // The same tile the sign-in screen shows. Here it is invisible against the
                // background it matches, which is the point: one mark, never recoloured.
                BrandTile()
                    .frame(width: Theme.Size.brandMark, height: Theme.Size.brandMark)

                Text("Gabay", comment: "The app's name, shown under the mark")
                    .font(Theme.Font.screenTitle)
                    .foregroundStyle(Theme.Color.onBrand)

                ProgressView()
                    .tint(Theme.Color.onBrand)
                    .padding(.top, Theme.Spacing.xl)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Starting up", comment: "Accessibility label for the launch screen"))
    }
}
