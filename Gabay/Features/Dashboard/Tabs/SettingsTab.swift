//
//  SettingsTab.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

struct SettingsTab: View {

    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        @Bindable var router = navigator.settings

        NavigationStack(path: $router.path) {
            SettingsView()
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .notifications:
                        NotificationsView()
                    case .blockedUsers:
                        BlockedUsersView()
                    }
                }
        }
        .environment(navigator.settings)
        .appAlert($router.alert)
    }
}
