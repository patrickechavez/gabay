//
//  TrackPoint.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import CoreLocation
import Foundation

// One fix along a trail: where, how high, and when.
struct TrackPoint: Equatable, Sendable {

    let latitude: Double

    let longitude: Double

    // Metres above sea level, absent in hand drawn routes.
    let elevation: Double?

    // Absent in a planned route, present in a recording.
    let time: Date?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // Metres to another point, along the surface of the earth.
    func distance(to other: TrackPoint) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

// A named line of points, however the file described it.
struct Track: Equatable, Sendable {

    var name: String?

    var points: [TrackPoint]
}

extension Array where Element == TrackPoint {

    // Metres walked, summing the gaps between consecutive points.
    var distance: Double {
        guard count > 1 else { return 0 }
        return zip(self, dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
    }

    // Metres climbed. Wobbles are ignored, or GPS drift makes a flat walk a mountain.
    func ascent(ignoringRisesUnder threshold: Double = 3) -> Double {
        var total = 0.0
        var reference: Double?

        for elevation in compactMap(\.elevation) {
            guard let last = reference else {
                reference = elevation
                continue
            }

            let change = elevation - last
            if change >= threshold {
                total += change
                reference = elevation
            } else if change <= -threshold {
                reference = elevation
            }
        }

        return total
    }

    // Metres to the start, so "am I near this" needs no camera move to answer.
    func distanceFromStart(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let start = first else { return nil }

        return CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    // Seconds between the first and last fix, nil for a route with no times.
    var duration: TimeInterval? {
        guard let first = first?.time, let last = last?.time else { return nil }
        return last.timeIntervalSince(first)
    }
}
