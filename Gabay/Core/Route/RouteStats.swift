//
//  RouteStats.swift
//  Gabay
//  Created by John Patrick Echavez on 9/23/26.
//

import Foundation

// Distance, climb, and estimated time, computed once from a parsed route by the organizer's phone and carried on the Event, instead of recomputed by every viewer like the free-trail app used to.
struct RouteStats: Equatable, Sendable {

    let distanceM: Double

    // Absent when the file carries no elevation, which is different from flat.
    let ascentM: Double?

    let estimatedMinutes: Int

    init(points: [TrackPoint]) {
        // Int(_:) traps on NaN, infinity, and anything past Int.max, and one non-finite coordinate makes the whole
        // sum non-finite. Points usually arrive validated from GPXParser, but this type is constructible from
        // anywhere, so it doesn't assume that; TrackPoint.validated only checks elevation for finiteness, so a
        // huge-but-finite value (1e19, say) can still reach here, and the Int.max bound below is what actually
        // stops it from trapping later in a consumer's Int(_:) conversion.
        let distance = points.distance
        distanceM = distance.isFinite && distance >= 0 && distance < Double(Int.max) ? distance : 0

        let hasElevation = points.contains { $0.elevation != nil }
        let ascent = hasElevation ? points.ascent() : nil
        ascentM = ascent.flatMap { $0.isFinite && $0 < Double(Int.max) ? $0 : nil }

        // Naismith's rule: 4 km an hour, plus an hour per 600 m climbed.
        let seconds = distanceM / 4000 * 3600 + (ascentM ?? 0) / 600 * 3600
        let minutes = (seconds / 60).rounded()
        estimatedMinutes = minutes.isFinite && minutes >= 0 && minutes < Double(Int.max)
            ? Int(minutes)
            : 0
    }
}
