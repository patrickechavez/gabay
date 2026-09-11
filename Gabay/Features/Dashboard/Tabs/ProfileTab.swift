//
//  ProfileTab.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

struct ProfileTab: View {

    let dependencies: AppDependencies

    @Environment(AppNavigator.self) private var navigator

    var body: some View {
        @Bindable var router = navigator.profile

        NavigationStack(path: $router.path) {
            ProfileView(viewModel: dependencies.makeProfileViewModel())
                .navigationDestination(for: ProfileRoute.self) { route in
                    switch route {
                    case .editProfile:
                        EditProfileView()
                    case .changePassword:
                        ChangePasswordView()
                    }
                }
        }
        .environment(navigator.profile)
        .appAlert($router.alert)
    }
}
