//
//  RouteSummary.swift
//  Gabay
//  Created by John Patrick Echavez on 9/25/26.
//

import Foundation

// The one-line "8.2 km - 386 m - ~2h 12m" under a route. Shared, because the organizer previewing
// an upload and the hiker reading the event must not disagree about the same numbers.
enum RouteSummary {

    static func text(distanceM: Double, ascentM: Double?, minutes: Int?) -> String {
        var parts = [distance(distanceM)]
        if let ascentM { parts.append(ascent(ascentM)) }
        if let minutes { parts.append(duration(minutes)) }
        return parts.joined(separator: " - ")
    }

    private static func distance(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private static func ascent(_ meters: Double) -> String {
        Measurement(value: meters, unit: UnitLength.meters)
            .formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            ))
    }

    // Drops an empty leading hour, so a 45 minute hike reads "~45m" and not "~0h 45m".
    private static func duration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60

        if hours == 0 { return "~\(remainder)m" }
        if remainder == 0 { return "~\(hours)h" }
        return "~\(hours)h \(remainder)m"
    }
}
