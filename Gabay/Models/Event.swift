//
//  Event.swift
//  Gabay
//  Created by John Patrick Echavez on 9/24/26.
//

import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
}

// Hashable, not merely Equatable: `.navigationDestination(item:)` in the events list requires it
// (same reason the free-trail app's Trail was Hashable).
struct Event: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let cause: String
    let date: Date
    let meetingPoint: String
    let meetingCoordinate: Coordinate
    let feePHP: Int
    let capacity: Int
    let joinURL: URL
    let description: String
    let photoURL: URL?
    let gpxURL: URL?
    let distanceM: Int?
    let ascentM: Int?
    let estimatedMinutes: Int?
    let status: Status

    enum Status: String, Codable, Sendable {
        case pending
        case published
    }
}

// What the organizer form sends: no id, status, or route stats, the backend assigns the first two
// and a route is added afterward through a separate upload.
struct EventDraft: Encodable, Sendable {
    let title: String
    let cause: String
    let date: Date
    let meetingPoint: String
    let meetingCoordinate: Coordinate
    let feePHP: Int
    let capacity: Int
    let joinURL: URL
    let description: String
    let photoURL: URL?
}
