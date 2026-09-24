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
        // A single non-finite coordinate makes the whole sum non-finite, and
        // Int(_:) traps on NaN, on infinity, and on anything past Int.max.
        // Points normally arrive validated from GPXParser, but this type is
        // constructible from anywhere, so it does not assume that. A point's
        // elevation is only checked for finiteness by TrackPoint.validated,
        // so a finite but enormous elevation (1e19, say) still reaches here;
        // the Int.max bound below is what actually keeps it from later
        // trapping in a consumer's Int(_:) conversion.
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
