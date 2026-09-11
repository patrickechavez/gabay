//
//  Activity.swift
//  Gabay
//  Created by John Patrick Echavez on 9/12/26.
//

import Foundation

// A walk that happened, as the history list needs to know it.
struct Activity: Identifiable, Hashable, Codable, Sendable {

    enum Kind: String, Codable, Sendable, CaseIterable {
        case walk, run, hike

        // What GPX calls it, so Strava sees a run rather than something unlabelled.
        var gpxType: String {
            switch self {
            case .walk: "walking"
            case .run: "running"
            case .hike: "hiking"
            }
        }
    }

    let id: String

    var name: String

    var kind: Kind

    let startedAt: Date

    let distance: Double

    // Nil when no fix carried a height, which is different from flat.
    let ascent: Double?

    let duration: TimeInterval

    // The trail this walk followed, if it followed one.
    var trailID: String?

    var formattedDistance: String {
        Measurement(value: distance, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    var formattedAscent: String? {
        guard let ascent else { return nil }

        return Measurement(value: ascent, unit: UnitLength.meters)
            .formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            ))
    }

    // Hours only when there were hours, so a short walk reads as 38:12.
    var formattedDuration: String {
        Duration.seconds(duration).formatted(
            .time(pattern: duration >= 3600 ? .hourMinuteSecond : .minuteSecond)
        )
    }

    // Minutes per kilometre. Meaningless before the first hundred metres.
    var formattedPace: String? {
        guard distance > 100, duration > 0 else { return nil }

        let seconds = Int((duration / (distance / 1000)).rounded())
        return String(format: "%d:%02d/km", seconds / 60, seconds % 60)
    }
}

extension Activity {

    // What a walk is called before anybody renames it.
    static func defaultName(for trail: String?, at date: Date, calendar: Calendar = .current) -> String {
        if let trail, !trail.isEmpty { return trail }

        return switch calendar.component(.hour, from: date) {
        case 4..<12: String(localized: "Morning walk", comment: "Default name for a walk recorded in the morning")
        case 12..<17: String(localized: "Afternoon walk", comment: "Default name for a walk recorded in the afternoon")
        case 17..<21: String(localized: "Evening walk", comment: "Default name for a walk recorded in the evening")
        default: String(localized: "Night walk", comment: "Default name for a walk recorded at night")
        }
    }
}
