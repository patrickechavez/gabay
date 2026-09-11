//
//  AppDependencies.swift
//  Gabay
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

@MainActor
final class AppDependencies {

    let analytics: any AnalyticsTracking
    let crashes: any CrashReporting

    let catalog: any TrailCatalogFetching

    private let trails: any TrailStoring

    init(
        catalog: any TrailCatalogFetching,
        trails: any TrailStoring,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting
    ) {
        self.catalog = catalog
        self.trails = trails
        self.analytics = analytics
        self.crashes = crashes
    }

    static func live() -> AppDependencies {
        // Nothing is reported anywhere, but the seams stay.
        let analytics = NoopAnalyticsTracker()
        let crashes = NoopCrashReporter()

        Observability.install(analytics: analytics, crashes: crashes)

        return AppDependencies(
            catalog: TrailCatalogClient(),
            trails: TrailStore(),
            analytics: analytics,
            crashes: crashes
        )
    }

    func makeTrailsViewModel() -> TrailsViewModel {
        TrailsViewModel(store: trails)
    }
}
