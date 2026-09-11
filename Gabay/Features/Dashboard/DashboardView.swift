//
//  DashboardView.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// The tab bar. Each tab lives in its own file and keeps its own screen stack.
struct DashboardView: View {

    let dependencies: AppDependencies

    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        @Bindable var navigator = navigator

        TabView(selection: $navigator.selectedTab) {
            HomeTab(dependencies: dependencies)
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            FavoritesTab()
                .tabItem { Label(AppTab.favorites.title, systemImage: AppTab.favorites.systemImage) }
                .tag(AppTab.favorites)

            ProfileTab(dependencies: dependencies)
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)

            SettingsTab()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage) }
                .tag(AppTab.settings)
        }
    }
}
