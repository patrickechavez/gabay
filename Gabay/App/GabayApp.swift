//
//  GabayApp.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI
import os

@main
struct GabayApp: App {

    @State private var dependencies: AppDependencies
    @State private var navigator: AppNavigator

    @Environment(\.scenePhase) private var scenePhase

    init() {
        let dependencies = AppDependencies.live()
        _dependencies = State(wrappedValue: dependencies)
        _navigator = State(
            wrappedValue: AppNavigator(parser: dependencies.deepLinks)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(navigator)
                .environmentRibbon()
                .onOpenURL { url in
                    navigator.open(url, isAuthenticated: true)
                }
                .onChange(of: scenePhase) { _, phase in
                    handle(phase)
                }
        }
    }

    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            AppLogger.lifecycle.debug("Scene active")
        case .background:
            AppLogger.lifecycle.debug("Scene backgrounded")
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
