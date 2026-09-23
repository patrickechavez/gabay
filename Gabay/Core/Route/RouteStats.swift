//
//  RouteStats.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

// Distance, climb, and an estimated time, computed once from a parsed
// route. The same numbers this app used to compute per free trail, now
// computed once by the organizer's phone and carried on the Event instead
// of recomputed by every viewer.
struct RouteStats: Equatable, Sendable {

    let distanceM: Double

    // Absent when the file carries no elevation, which is different from flat.
    let ascentM: Double?

    let estimatedMinutes: Int

    init(points: [TrackPoint]) {
        distanceM = points.distance

        let hasElevation = points.contains { $0.elevation != nil }
        let ascent = hasElevation ? points.ascent() : nil
        ascentM = ascent

        // Naismith's rule: 4 km an hour, plus an hour per 600 m climbed.
        let seconds = distanceM / 4000 * 3600 + (ascent ?? 0) / 600 * 3600
        estimatedMinutes = Int((seconds / 60).rounded())
    }
}
