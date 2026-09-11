//
//  GabayApp.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI
import UIKit
import os

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Not in App.init() — reporters aren't installed yet, and debug always attaches.
        #if !DEBUG
        reportDeviceSecurity()
        #endif
        return true
    }

    /// Report-only hardening checks. Flags the device, never blocks it.
    private func reportDeviceSecurity() {
        if DefaultJailbreakDetector().isJailbroken {
            Observability.analytics.track("device_jailbroken")
            AppLogger.lifecycle.warning("Jailbreak indicators detected on device")
        }

        if DefaultDebuggerDetector().isDebuggerAttached {
            Observability.analytics.track("debugger_attached")
            AppLogger.lifecycle.warning("Debugger is attached to the process")
        }
    }
}

@main
struct GabayApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var dependencies: AppDependencies
    @State private var navigator: AppNavigator

    @Environment(\.scenePhase) private var scenePhase

    // Covers the screen while the app is away; see updateShield.
    @State private var isShielded = false

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
                .overlay {
                    if isShielded {
                        PrivacyShieldView()
                    }
                }
                .environmentRibbon()

                .onOpenURL { url in
                    navigator.open(url, isAuthenticated: dependencies.session.state == .authenticated)
                }

                .onChange(of: dependencies.session.state) { _, state in
                    switch state {
                    case .authenticated:
                        navigator.resumePendingLink()
                    case .unauthenticated:
                        navigator.reset()
                    case .bootstrapping:
                        break
                    }
                }
                .onChange(of: scenePhase, initial: true) { previous, phase in
                    updateShield(from: previous, to: phase)
                    handle(phase)
                }
                .onReceive(ScreenshotDetector.publisher) { _ in
                    dependencies.analytics.track("screenshot_captured")
                }
        }
    }

    /// Raised on the way out, lowered on the way back — "not active" would linger.
    private func updateShield(from previous: ScenePhase, to phase: ScenePhase) {
        switch phase {
        case .active:
            isShielded = false
        case .background:
            isShielded = true
        case .inactive:
            isShielded = previous == .active
        @unknown default:
            isShielded = false
        }
    }

    private func handle(_ phase: ScenePhase) {
        switch phase {
        case .active:
            AppLogger.lifecycle.debug("Scene active")
        case .background:
            AppLogger.lifecycle.debug("Scene backgrounded")

            Task { await ImageLoader.shared.trimMemory() }
        case .inactive:
            break
        @unknown default:
            break
        }
    }

}
