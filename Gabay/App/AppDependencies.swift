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

    let catalog: any TrailCatalogFetching

    private let trails: any TrailStoring

    init(
        catalog: any TrailCatalogFetching,
        trails: any TrailStoring,
        deepLinks: DeepLinkParser,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting
    ) {
        self.catalog = catalog
        self.trails = trails
        self.deepLinks = deepLinks
        self.analytics = analytics
        self.crashes = crashes
    }

    static func live() -> AppDependencies {
        // Nothing is reported anywhere. The seams stay so a screen can record a
        // breadcrumb without knowing that nobody is listening.
        let analytics = NoopAnalyticsTracker()
        let crashes = NoopCrashReporter()

        Observability.install(analytics: analytics, crashes: crashes)

        return AppDependencies(
            catalog: TrailCatalogClient(),
            trails: TrailStore(),
            deepLinks: DeepLinkParser(),
            analytics: analytics,
            crashes: crashes
        )
    }

    func makeTrailsViewModel() -> TrailsViewModel {
        TrailsViewModel(store: trails)
    }
}
