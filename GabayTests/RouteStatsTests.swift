//
//  RouteStatsTests.swift
//  GabayTests
//

import Foundation
import Testing
@testable import Gabay

struct RouteStatsTests {

    private func points(_ elevations: [Double?]) -> [TrackPoint] {
        elevations.enumerated().map { index, elevation in
            // Roughly 111 metres of latitude per 0.001 degrees.
            TrackPoint(
                latitude: 9.8127 + Double(index) * 0.001,
                longitude: 123.3878,
                elevation: elevation,
                time: nil
            )
        }
    }

    @Test func computesDistanceAndAscent() {
        let stats = RouteStats(points: points([100, 150, 200]))

        #expect(stats.distanceM > 0)
        #expect(stats.ascentM == 100)
    }

    @Test func leavesAscentNilWithoutElevation() {
        let stats = RouteStats(points: points([nil, nil, nil]))

        #expect(stats.ascentM == nil)
    }

    @Test func estimatesMoreTimeForAClimbingRouteThanAFlatOne() {
        let flat = RouteStats(points: points([100, 100, 100]))
        let climbing = RouteStats(points: points([100, 400, 700]))

        #expect(climbing.estimatedMinutes > flat.estimatedMinutes)
    }

    // 4000m flat at 4 km/h (Naismith's baseline pace) is exactly 60 minutes.
    @Test func matchesNaismithsBaselinePaceOnAFlatRoute() {
        let stats = RouteStats(points: [
            TrackPoint(latitude: 0, longitude: 0, elevation: 100, time: nil),
            TrackPoint(latitude: 0.036, longitude: 0, elevation: 100, time: nil)
        ])

        #expect(stats.estimatedMinutes >= 55 && stats.estimatedMinutes <= 65)
    }

    @Test func survivesANonFiniteCoordinate() {
        let broken = [
            TrackPoint(latitude: .nan, longitude: 123.3878, elevation: nil, time: nil),
            TrackPoint(latitude: 9.8127, longitude: 123.3878, elevation: nil, time: nil)
        ]

        let stats = RouteStats(points: broken)

        #expect(stats.estimatedMinutes == 0)
        #expect(stats.distanceM.isFinite)
    }

    @Test func anInfiniteCoordinateIsNeutralisedByCoreLocationBeforeAnyGuardRuns() {
        // This is not crash-path coverage: CLLocation.distance(from:) with an
        // infinite latitude was measured to return 0.0, not infinity or NaN,
        // so points.distance is already 0 here regardless of the RouteStats
        // guards. NaN is the coordinate value that actually propagates and
        // needs the guard; survivesANonFiniteCoordinate covers that case.
        // This test only records that an infinite coordinate stays harmless,
        // a property worth guarding against regressing if CoreLocation's or
        // this code's behavior around it ever changes.
        let broken = [
            TrackPoint(latitude: .infinity, longitude: 123.3878, elevation: nil, time: nil),
            TrackPoint(latitude: 9.8127, longitude: 123.3878, elevation: nil, time: nil)
        ]

        let stats = RouteStats(points: broken)

        #expect(stats.estimatedMinutes == 0)
        #expect(stats.distanceM.isFinite)
    }

    @Test func survivesANonFiniteElevation() {
        // A finite elevation followed by an infinite one drives ascent()
        // itself non-finite: change = .infinity - 100 = .infinity, which
        // accumulates straight into total. The ascentM guard must turn
        // that into nil rather than let it propagate into the estimate.
        let broken = points([100, .infinity])
        let flat = points([100, 100])

        let stats = RouteStats(points: broken)
        let flatStats = RouteStats(points: flat)

        #expect(stats.ascentM == nil)
        #expect(stats.estimatedMinutes == flatStats.estimatedMinutes)
    }

    @Test func treatsNaNElevationAsNoClimbRatherThanCrashing() {
        // The fixture the old test used never reaches the ascentM guard:
        // reference becomes NaN on the first point, and NaN compares false
        // against both the climb and drop thresholds in ascent(), so
        // nothing ever accumulates. The route is scored as flat, not
        // crashed.
        let broken = points([.nan, .infinity])
        let flat = points([100, 100])

        let stats = RouteStats(points: broken)
        let flatStats = RouteStats(points: flat)

        #expect(stats.ascentM == 0)
        #expect(stats.estimatedMinutes == flatStats.estimatedMinutes)
    }

    @Test func rejectsAFiniteButEnormousElevation() {
        // 1e19 is finite, so TrackPoint.validated and the old isFinite-only
        // ascentM guard both let it through. It is also past Double(Int.max),
        // so Int(_:) on it would trap. The bound must catch it here, at the
        // one place every Int conversion of ascentM reads from.
        let broken = points([100, 1e19])
        let flat = points([100, 100])

        let stats = RouteStats(points: broken)
        let flatStats = RouteStats(points: flat)

        #expect(stats.ascentM == nil)
        #expect(stats.estimatedMinutes == flatStats.estimatedMinutes)
    }

    @Test func doesNotClampAPlausibleMountainElevation() {
        // A real mountain's elevation gain is nowhere near Double(Int.max),
        // so the new bound must leave it alone.
        let stats = RouteStats(points: points([0, 8000]))

        #expect(stats.ascentM == 8000)
    }

    @Test func leavesAWellFormedRouteUnchanged() {
        // A regression guard: the new arithmetic must not alter a valid route.
        let stats = RouteStats(points: points([100, 150, 200]))

        #expect(stats.distanceM.isFinite)
        #expect(stats.ascentM == 100)
        #expect(stats.estimatedMinutes > 0)
    }
}
