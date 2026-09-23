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
}
