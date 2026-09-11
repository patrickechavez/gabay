//
//  AppDependencies.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

@MainActor
final class AppDependencies {

    let deepLinks: DeepLinkParser
    let analytics: any AnalyticsTracking
    let crashes: any CrashReporting
    let network: NetworkMonitor

    private let imageLoader: any ImageLoading

    init(
        imageLoader: any ImageLoading,
        deepLinks: DeepLinkParser,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting,
        network: NetworkMonitor = NetworkMonitor()
    ) {
        self.imageLoader = imageLoader
        self.deepLinks = deepLinks
        self.analytics = analytics
        self.crashes = crashes
        self.network = network
    }

    static func live() -> AppDependencies {
        // Nothing is reported anywhere. The seams stay so a screen can record a
        // breadcrumb without knowing that nobody is listening.
        let analytics = NoopAnalyticsTracker()
        let crashes = NoopCrashReporter()

        Observability.install(analytics: analytics, crashes: crashes)

        return AppDependencies(
            imageLoader: ImageLoader.shared,
            deepLinks: DeepLinkParser(),
            analytics: analytics,
            crashes: crashes
        )
    }
}
