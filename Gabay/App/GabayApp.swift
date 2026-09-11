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

    @Environment(\.scenePhase) private var scenePhase

    init() {
        _dependencies = State(wrappedValue: AppDependencies.live())
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environmentRibbon()
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
