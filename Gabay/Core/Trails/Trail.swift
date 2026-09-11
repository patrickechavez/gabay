//
//  Trail.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// What the list knows: enough to decide whether to go, without opening the file.
struct Trail: Identifiable, Hashable, Sendable {

    enum Difficulty: String, Codable, Sendable, CaseIterable {
        case easy, moderate, hard
    }

    // Where the trail came from.
    enum Source: Hashable, Sendable {
        case catalog
        case imported
    }

    let id: String

    let name: String

    let region: String

    let distance: Double

    // Absent when the file carries no elevation, which is different from flat.
    let ascent: Double?

    let difficulty: Difficulty

    var source: Source = .catalog

    // False while the trail is still only a row in the catalog.
    var isOnDevice: Bool = false

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

    // Naismith's rule: 4km an hour, plus an hour per 600 metres climbed.
    var estimatedDuration: TimeInterval {
        distance / 4000 * 3600 + (ascent ?? 0) / 600 * 3600
    }
}

extension Trail {

    // Builds the list row from a catalog entry, before anything is downloaded.
    init(_ entry: CatalogTrail, isOnDevice: Bool) {
        self.init(
            id: entry.id,
            name: entry.name,
            region: entry.region,
            distance: Double(entry.distanceM),
            ascent: Double(entry.ascentM),
            difficulty: Difficulty(rawValue: entry.difficulty) ?? .moderate,
            source: .catalog,
            isOnDevice: isOnDevice
        )
    }

    // Builds one from an imported file, measuring what a catalog would have told us.
    init(imported document: GPXDocument, id: String, fallbackName: String) {
        let points = document.points
        let hasElevation = points.contains { $0.elevation != nil }

        self.init(
            id: id,
            name: document.name ?? document.tracks.first?.name ?? fallbackName,
            region: "",
            distance: points.distance,
            ascent: hasElevation ? points.ascent() : nil,
            difficulty: .moderate,
            source: .imported,
            isOnDevice: true
        )
    }
}
