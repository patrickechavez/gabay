//
//  HomeTab.swift
//  Gabay
//  Created by John Patrick Echavez on 9/2/26.
//

import SwiftUI

struct HomeTab: View {

    let dependencies: AppDependencies

    @Environment(AppNavigator.self) private var navigator

    @SceneStorage("home.path") private var storedPath: Data?

    var body: some View {
        @Bindable var router = navigator.home

        NavigationStack(path: $router.path) {
            HomeView(viewModel: dependencies.makeHomeViewModel())
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case let .itemDetail(id):
                        ItemDetailView(viewModel: dependencies.makeItemDetailViewModel(id: id))
                    case let .itemReviews(id):
                        ItemReviewsView(itemID: id)
                    }
                }
        }
        .environment(navigator.home)
        .appAlert($router.alert)
        .task {
            navigator.home.restore(from: storedPath)
        }
        .onChange(of: navigator.home.path) { _, _ in
            storedPath = navigator.home.restorationData
        }
    }
}
