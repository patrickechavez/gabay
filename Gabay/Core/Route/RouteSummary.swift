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

    // Duration.UnitsFormatStyle localizes the unit names and already drops an empty leading hour,
    // so a 45 minute hike reads "45 min" and not "0 hr, 45 min". The hand-built "~2h 12m" it
    // replaces hardcoded English in a file that localizes everything else.
    private static func duration(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}
