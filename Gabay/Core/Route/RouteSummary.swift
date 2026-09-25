//
//  RouteSummary.swift
//  Gabay
//  Created by John Patrick Echavez on 9/25/26.
//

import Foundation

// The one-line "8.2 km - 386 m - ~2 hr, 12 min" under a route. Shared, because the organizer
// previewing an upload and the hiker reading the event must not disagree about the same numbers.
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

    // Duration.UnitsFormatStyle localizes the unit names and already drops an empty leading hour,
    // so a 45 minute hike reads "45 min" and not "0 hr, 45 min".
    //
    // Converted through Double first: `minutes * 60` traps on overflow, and `estimatedMinutes`
    // is an unclamped Int decoded straight from the API. The "~" stays because this is Naismith's
    // estimate, not a measurement.
    private static func duration(_ minutes: Int) -> String {
        let formatted = Duration.seconds(Double(minutes) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return "~\(formatted)"
    }
}
