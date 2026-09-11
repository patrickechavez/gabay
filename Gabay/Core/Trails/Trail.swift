//
//  Trail.swift
//  Gabay
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// A trail as the list knows it: enough to decide whether to go, without
// reading the file.
struct Trail: Identifiable, Equatable, Sendable {

    enum Difficulty: String, Codable, Sendable, CaseIterable {
        case easy, moderate, hard
    }

    // Where the trail came from, which is the only thing the list treats
    // differently.
    enum Source: Equatable, Sendable {
        case catalog
        case imported
    }

    let id: String

    let name: String

    let region: String

    let distance: Double

    let ascent: Double

    let difficulty: Difficulty

    var source: Source = .catalog

    // False while the trail is still only a row in the catalog.
    var isOnDevice: Bool = false

    var formattedDistance: String {
        Measurement(value: distance, unit: UnitLength.meters)
            .converted(to: .kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    var formattedAscent: String {
        Measurement(value: ascent, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided))
    }

    // Naismith's rule: 4km an hour on the flat, plus an hour for every 600
    // metres climbed. Rough, and every hiker knows it is rough.
    var estimatedDuration: TimeInterval {
        distance / 4000 * 3600 + ascent / 600 * 3600
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

    // Builds one from a file the user imported, where the numbers have to be
    // measured rather than read.
    init(imported document: GPXDocument, id: String, fallbackName: String) {
        let points = document.points

        self.init(
            id: id,
            name: document.name ?? document.tracks.first?.name ?? fallbackName,
            region: "",
            distance: points.distance,
            ascent: points.ascent(),
            difficulty: .moderate,
            source: .imported,
            isOnDevice: true
        )
    }
}
