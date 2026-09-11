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
    private let cache: any CatalogCaching
    private let activities: any ActivityStoring

    // One recorder for the app: a walk outlives the screen that started it.
    let recorder: Recorder

    init(
        catalog: any TrailCatalogFetching,
        trails: any TrailStoring,
        cache: any CatalogCaching,
        activities: any ActivityStoring,
        locations: any LocationStreaming,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting
    ) {
        self.catalog = catalog
        self.trails = trails
        self.cache = cache
        self.activities = activities
        recorder = Recorder(store: activities, locations: locations)
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
            cache: CatalogCache(),
            activities: ActivityStore(),
            locations: LiveLocationStream(),
            analytics: analytics,
            crashes: crashes
        )
    }

    func makeTrailsViewModel() -> TrailsViewModel {
        TrailsViewModel(store: trails, catalog: catalog, cache: cache)
    }

    func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(store: activities)
    }
}
